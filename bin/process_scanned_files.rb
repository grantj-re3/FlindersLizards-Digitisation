#!/usr/bin/ruby
#
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Usage:  process_scanned_files.rb
#
# Algorithm:
# - For each file in IN_SCAN_DIR
#   * Process scan files
#   * Create CSV file containing key,filename & other misc fields.
#   * Report key-ranges of: gaps, single files & overlaps (ie. multiple files).
#   * Report if expected number of pages differs from actual number.
#   * FUTURE: Report trip no by year? Eg. Must be different years?
##############################################################################
# Add dirs to the library path
$: << File.expand_path("../etc", File.dirname(__FILE__))
$: << File.expand_path("../lib/libext", File.dirname(__FILE__))

require "common_config"
require "date"
require 'faster_csv'

##############################################################################
class FileRegisterInfo
  DELIM_MISSING_KEY = "|"

  attr_reader :filename, :num_sheets_front, :num_sheets_back,
    #:num_sheets_body, :num_pages_expected, :num_keys,
    :num_keys_missing, :ok

  def initialize(line)
    # FIXME: Consider checking numeric fields with a regex? Interpret "-" as zero.
    @filename = line["Filename"]

    # Note: 1 sheet = 2 pages if double-sided
    @num_sheets_front = line["# Day sheets"] ? line["# Day sheets"].to_i : nil
    @num_sheets_back = line["# Trip file"] ? line["# Trip file"].to_i : nil
    #@num_sheets_body = line["# Capture sheets"] ? line["# Capture sheets"].to_i : nil
    #@num_pages_expected = line["Expected pages"] ? line["Expected pages"].to_i : nil

    #@num_keys = line["No. keys"] ? line["No. keys"].to_i : nil
    @num_keys_missing = line["Missing Key #"].to_s.strip.split(DELIM_MISSING_KEY).length

    @ok = @filename && @num_sheets_front && @num_sheets_back &&
      #@num_sheets_body && @num_pages_expected && @num_keys &&
      @num_keys_missing
  end
end

##############################################################################
class ScannedFilesProcessor
  include CommonConfig

  DEBUG = false

  # These parameters allow you to process a subset of scan-files (typically
  # for debugging purposes).
  #
  # To process only the third scan-file, set min to 3 & max to 3.
  # To process all scan-files, set min to 1 & max to something like 99999.
  MIN_SCANFILE_COUNT = MIN_FILE_COUNT
  MAX_SCANFILE_COUNT = MAX_FILE_COUNT

  PERMITTED_FILE_EXTENSIONS = %w{pdf}
  PERMITTED_FILE_EXTENSIONS_REGEX = Regexp.new(
    "^(.*)\\.(#{PERMITTED_FILE_EXTENSIONS.join('|')})$",
    Regexp::IGNORECASE
  )

  FILENAME_SEP = "_"
  FILENAME_SEP_MIN = 3
  FILENAME_SEP_MAX = 3
  FILENAME_PARTS_RNG = (FILENAME_SEP_MIN+2)..(FILENAME_SEP_MAX+2)

  FILENAME_PARTS_REGEX = [
    /^slls$/,			# Filename prefix
    /^d(\d{4})(\d{2})(\d{2})$/,	# Date: dYYYYMMDD
    /^t(\d+[a-z]?)$/,		# Trip no: tJJJa
    /^k(\d+)-(\d+)$/,		# Key range: kNNN-MMM
  ]

  # FIXME: Consider sanity check for date (not just year)
  KEY_RANGE = 1..56392
  KEY_RANGE_NONE = 0..0
  YEAR_RANGE = 1982..2017
  TRIP_RANGE = 1..17467

  # String describing the type of line in the gap (& overlap) report
  TYPE_S = {
    :normal	=> "",		# This range of keys is specified exactly once
    :gap	=> "gap",	# There is a gap in the list of keys
    :overlap	=> "overlap",	# There is an overlap in the list of keys
  }

  PDFINFO_EXE = "/usr/bin/pdfinfo"

  # Quote & delim chars of the input CSV file
  QUOTE = '"'
  DELIM=','

  attr_reader :info_by_mms_id

  ############################################################################
  def initialize
    @target_fnames = []
    @fileparts_list = []
    @fileparts_no_keys_list = []
    @bad_fnames = nil

    @files_by_sorted_trip = []
    @file_reg_db = {}		# File-register database (from Lizard filename register )
  end

  ############################################################################
  def collect_target_filenames
    scanfile_count = 0
    @target_fnames = []
    Dir.entries(IN_SCAN_DIR).sort.each{|f|
      next if File.directory?("#{IN_SCAN_DIR}/#{f}")
      scanfile_count += 1

      next if scanfile_count < MIN_SCANFILE_COUNT
      break if scanfile_count > MAX_SCANFILE_COUNT
      @target_fnames << f		# Process this scan-file
    }
    if @target_fnames.length == 0
      puts "Quitting! No files to process in folder #{IN_SCAN_DIR}"
      exit 0
    end
  end

  ############################################################################
  def self.get_date_s(parts, index)
    return nil unless parts[index].match(FILENAME_PARTS_REGEX[index])
    yyyy = $1.to_i
    mm   = $2.to_i
    dd   = $3.to_i
    yyyymmdd_s = "%04d-%02d-%02d" % [yyyy, mm, dd]	# YYYY-MM-DD

    begin
      date = Date.strptime(yyyymmdd_s, "%F")
    rescue
      return nil					# Invalid date format
    end
    return nil unless yyyymmdd_s == date.strftime("%F")	# Mis-interpretation of YYYY-MM-DD
    return nil unless YEAR_RANGE.include?(yyyy)
    return yyyymmdd_s
  end

  ############################################################################
  def self.get_trip_s(parts, index)
    return nil unless parts[index].match(FILENAME_PARTS_REGEX[index])
    return $1
  end

  ############################################################################
  def self.get_key_range(parts, index)
    return nil unless parts[index].match(FILENAME_PARTS_REGEX[index])

    key_begin = $1.to_i
    key_end   = $2.to_i
    return KEY_RANGE_NONE if key_begin == 0 && key_end == 0	# Special case if no capture sheets

    return nil unless KEY_RANGE.include?(key_begin) && KEY_RANGE.include?(key_end)
    return nil unless key_end >= key_begin
    return key_begin..key_end
  end

  ############################################################################
  def collect_target_fileparts
    f_invalid_exts = []; f_bad_num_sep = []; f_empty_part = []
    f_bad_prefix = []; f_bad_date = []; f_bad_trip = []; f_bad_key_range = []

    @fileparts_list = []
    @fileparts_no_keys_list = []
    @target_fnames.each_with_index{|f,tf_index|
      if f.match(PERMITTED_FILE_EXTENSIONS_REGEX)
        basename, ext = $1, $2
        parts = basename.split(FILENAME_SEP) + [ ext ]
        has_descr = parts.length == FILENAME_PARTS_RNG.end

        if FILENAME_PARTS_RNG.include?(parts.length)
          if parts.include?("")
            f_empty_part << f
          else
            # Check each part (with regex): slls_dYYYYMMDD_tTRIPNO_kKEYBEGIN-KEYEND.EXT
            date_s = self.class.get_date_s(parts, 1)
            trip_s = self.class.get_trip_s(parts, 2)
            key_range = self.class.get_key_range(parts, 3)

            is_ok = true
            (f_bad_prefix    << f; is_ok = false) unless parts[0].match(FILENAME_PARTS_REGEX[0])
            (f_bad_date      << f; is_ok = false) unless date_s
            (f_bad_trip      << f; is_ok = false) unless trip_s
            (f_bad_key_range << f; is_ok = false) unless key_range

            if is_ok
              fname_parts = {
                :whole		=> f,			# Eg. slls_d19860930_t241a_k4794-4802.pdf
                :date_s		=> date_s,		# Eg. "1986-09-30"
                :trip_s		=> trip_s,		# Eg. "241a"
                :key_range	=> key_range,		# Eg. 4794..4802
                :ext		=> parts.last		# Eg. "pdf"
              }
              if key_range == KEY_RANGE_NONE
                @fileparts_no_keys_list << fname_parts
              else
                @fileparts_list << fname_parts
              end
            end
          end
        else
          f_bad_num_sep << f
        end
      else
        f_invalid_exts << f
      end
    }
    @bad_fnames = [
      # [sort_num, key,		bad_file_list,	regex_index]
      [100, :invalid_exts,	f_invalid_exts,		nil],
      [200, :bad_num_sep,	f_bad_num_sep,		nil],
      [300, :empty_part,	f_empty_part,		nil],

      [400, :bad_prefix,	f_bad_prefix,		0],
      [410, :bad_date,		f_bad_date,		1],
      [420, :bad_trip,		f_bad_trip,		2],
      [430, :bad_key_range,	f_bad_key_range,	3],
    ]
    show_bad_target_filenames
  end

  ############################################################################
  def show_bad_target_filenames
    @bad_fnames.sort{|a,b| a[0] <=> b[0]}.each{|sort,key,a,idx|
      next if a.empty?

      debug1 = "[#{sort}, #{key}] "
      #debug1 = ""

      desc = case key
      when :invalid_exts
	<<-EO_MSG
		#{debug1}The following files have an invalid file extension.
		Valid file extensions are: #{PERMITTED_FILE_EXTENSIONS.join(', ')}
	EO_MSG

      when :bad_num_sep
		"#{debug1}The following files have the wrong number of separators '#{FILENAME_SEP}'."

      when :empty_part
	<<-EO_MSG
		#{debug1}Filenames are divided into parts by the separator '#{FILENAME_SEP}'.
		None of the parts (PREFIX, DATE, TRIPNO, KEYBEGIN-KEYEND)
		are allowed to be empty.
	EO_MSG

      when :bad_prefix
		"#{debug1}PREFIX is invalid! Must match: #{FILENAME_PARTS_REGEX[idx].inspect}"

      when :bad_date
	<<-EO_MSG
		#{debug1}DATE is invalid!
		Must match: YYYYMMDD
		YYYY must be in range: #{YEAR_RANGE}
		Must match: #{FILENAME_PARTS_REGEX[idx].inspect}
	EO_MSG

      when :bad_trip
		"#{debug1}TRIPNO is invalid! Must match: #{FILENAME_PARTS_REGEX[idx].inspect}"

      when :bad_key_range
	<<-EO_MSG
		#{debug1}KEYBEGIN-KEYEND is invalid!
		Must be in range: #{KEY_RANGE}
		KEYEND must not be less than KEYBEGIN
		Must match: #{FILENAME_PARTS_REGEX[idx].inspect}
	EO_MSG

      else
        "#{debug1}"
      end

      STDERR.puts "\n#{desc.gsub(/^\t*/, '')}"
      a.each{|f| STDERR.puts "- #{f}"}
    }

    unless @bad_fnames.all?{|(sort,key,a,idx)| a.empty?}
      STDERR.puts <<-EO_MSG.gsub(/^\t*/, '')

		Filename format must be as follows:
		    slls_dYYYYMMDD_tTRIPNO_kKEYBEGIN-KEYEND.EXT
		Eg. slls_d19860930_t241_k4794-4802.pdf
		If there are no capture sheets, KEYBEGIN & KEYEND shall both be zero.
		Eg. slls_d19860930_t241_k0-0.pdf

		Quitting: Some filenames are invalid!
	EO_MSG
      exit 1
    end
  end

  ############################################################################
  def sort_by_key
    [@fileparts_list, @fileparts_no_keys_list].each{|a|
      a.sort!{|a,b|
        a[:key_range] == b[:key_range] ?
          ( a[:date_s] == b[:date_s] ?
              a[:trip_s] <=> b[:trip_s] :
              a[:date_s] <=> b[:date_s]
          ) :
          a[:key_range].begin <=> b[:key_range].begin
      }
    }
  end

  ############################################################################
  # List all the keys (one per line) and the associated filename.
  def create_key_csv
    puts "Creating key CSV file (#{File.basename(FNAME_KEYS_CSV)}) ..."
    File.open(FNAME_KEYS_CSV, 'w'){|fh|
      fh.puts "key,filename,date,trip"		# CSV header line
      @fileparts_list.each{|p|
        # CSV data lines
        p[:key_range].each{|key| fh.puts "%d,%s,%s,%s" % [key, p[:whole], p[:date_s], p[:trip_s]]}
      }
    }
  end

  ############################################################################
  # List pairs of files which have overlapping keys.
  def create_key_overlap_report
    puts "Creating key-overlap report (#{File.basename(FNAME_KEY_OVERLAP_CSV)}) ..."
    File.open(FNAME_KEY_OVERLAP_CSV, 'w'){|fh|
      fh.puts "overlap_file1,overlap_file2"	# CSV header line
      @fileparts_list.each_with_index{|p1,i|
        rng = (i+1)..p1[:key_range].end		# Compare with keys further up the array
        @fileparts_list[rng].each{|p2|
          if p1[:key_range].include?(p2[:key_range].begin) || p1[:key_range].include?(p2[:key_range].end)
            # CSV data line
            fh.puts "%s,%s" % [p1[:whole], p2[:whole]]
          end
        }
      }
    }
  end

  ############################################################################
  # List key-ranges which have gaps; key-ranges associated with a single
  # file; and key-ranges associated with multiple files (ie. overlaps).
  def create_key_gap_report
    # Overlap lines:
    # If the key-range of any file A overlaps with that of another file B,
    # those key-ranges are combined and flagged as an overlap.  If that
    # combined key range overlaps with yet another in file C, the key-ranges
    # are combined again. This process is repeated and the resulting
    # key-range is shown on a single line. Hence there is less detail in
    # such lines than in the Overlap Report.
    puts "Creating key-gap report (#{File.basename(FNAME_KEY_GAP_CSV)}) ..."
    # Assumes @fileparts_list has been sorted numerically by KEY_BEGIN.
    range = nil; type = nil; files = nil

    File.open(FNAME_KEY_GAP_CSV, 'w'){|fh|
      fh.puts "key_begin,key_end,gap_overlap,files"		# CSV header line

      # We might start with a gap
      if KEY_RANGE.begin < @fileparts_list.first[:key_range].begin
        fh.puts "%d,%d,%s,%s" % [KEY_RANGE.begin, @fileparts_list.first[:key_range].begin-1, TYPE_S[:gap], ""]
      end

      do_next = true
      @fileparts_list.each_with_index{|p,i|
        if i == 0
          # First iteration: No processing

	elsif range.include?(p[:key_range].begin) || range.include?(p[:key_range].end)
          # Overlap: The range.end might be greater than current value
          range = range.begin..p[:key_range].end if p[:key_range].end > range.end
          type = :overlap
          files << p[:whole]
          do_next = false

        elsif range.end+1 == p[:key_range].begin
          # This range continues immediately from old range: Write old range line.
          fh.puts "%d,%d,%s,%s" % [range.begin, range.end, TYPE_S[type], files.join("|")]

        else	# There must be a gap: Write old range line. Write gap line.
          fh.puts "%d,%d,%s,%s" % [range.begin, range.end, TYPE_S[type], files.join("|")]
          fh.puts "%d,%d,%s,%s" % [range.end+1, p[:key_range].begin-1, TYPE_S[:gap], ""]
        end

        if do_next
          range = p[:key_range]
          type = :normal
          files = [ p[:whole] ]
        end
        do_next = true
      }	# Each

      # Write last range
      fh.puts "%d,%d,%s,%s" % [range.begin, range.end, TYPE_S[type], files.join("|")]

      # We might end with a gap
      if @fileparts_list.last[:key_range].end < KEY_RANGE.end
        fh.puts "%d,%d,%s,%s" % [@fileparts_list.last[:key_range].end+1, KEY_RANGE.end, TYPE_S[:gap], ""]
      end
    }	# File.open
  end

  ############################################################################
  # List the scan files which have no associated keys.
  def create_no_keys_report
    puts "Creating no-keys CSV file (#{File.basename(FNAME_NO_KEYS_CSV)}) ..."
    File.open(FNAME_NO_KEYS_CSV, 'w'){|fh|
      fh.puts "date,trip,file_without_keys"	# CSV header line
      @fileparts_no_keys_list.each{|p|
        # CSV data lines
        fh.puts "%s,%s,%s" % [p[:date_s], p[:trip_s], p[:whole]]
      }
    }
  end

  ############################################################################
  # FIXME: It would be nicer to re-write this method using a Ruby library/gem
  # like https://github.com/yob/pdf-reader; but I am using Ruby 1.8.7 & this
  # library requires Ruby 2.1.
  def get_pdf_npages(fpath)
      cmd = "#{PDFINFO_EXE} \"#{fpath}\" 2>&1"
      output = %x{ #{cmd} }
      return nil unless $?.to_s == "0"		# Bad return code from command line

      output.find{|line| line.match(/^Pages:\s+(\d+)/)}
      npages_s = $1
      return nil unless npages_s		# No regex match
      npages_s.to_i
  end

  ############################################################################
  def get_expected_npages(fileparts)
    npages_extra = 3				# 2x Day Sheet; 1x Trip File
    range = fileparts[:key_range]
    npages_capture = range == KEY_RANGE_NONE ? 0 : range.end - range.begin + 1
    npages_capture * 2 + npages_extra
  end

  ############################################################################
  # For each file, list the actual and expected number of pages
  def create_num_pages_report(report_type=:actual)
    report_type = :expected unless report_type == :actual
    fname_out = report_type == :actual ? FNAME_NUM_PAGES_ACTUAL_CSV : FNAME_NUM_PAGES_EXPECTED_CSV
    puts "Creating #{report_type} number-of-pages CSV file (#{File.basename(fname_out)}) ..."
    File.open(fname_out, 'w'){|fh|
      fh.puts "filename,actual_npages,%scomment" % [report_type == :actual ? "" : "expected_npages,"]	# CSV header line

      @fileparts_list.each{|p|
        fpath = "#{IN_SCAN_DIR}/#{p[:whole]}"
        npages = get_pdf_npages(fpath)
        npages_expected = report_type == :actual ? npages : get_expected_npages(p)

        fh.puts "%s,%s,%s%s" % [
          p[:whole],
          npages.to_s,
          report_type == :actual ? "" : "#{npages_expected},",
          !npages ? "Cannot read number of pages. Is the file-type PDF?" :
            (npages != npages_expected ? "Unexpected number of pages" : "")
        ]
      }
    }
  end

  ############################################################################
  # Load the filename register (CSV "database") into a hash
  def load_file_reg_db
    opts = {
      :col_sep => DELIM,
      :headers => true,
      #:header_converters => :symbol,
      :quote_char => QUOTE,
    }
    unless File.exists?(IN_FNAME_REG_CSV)
      @file_reg_db = nil
      return
    end

    @file_reg_db = {}
    FasterCSV.foreach(IN_FNAME_REG_CSV, opts) {|line|
      info = FileRegisterInfo.new(line)
      f = info.filename
      @file_reg_db[f] = info unless f.nil? || f.match(/_k-.pdf$/)
    }
  end

  ############################################################################
  # Calculate the number of expected pages (using the least amount of
  # info from the register as possible)
  def get_expected_npages_from_file_register(fileparts)
    # Note: 1 sheet = 2 pages if double-sided
    fname = fileparts[:whole]
    if DEBUG
      puts
      puts "  fileparts           : #{fileparts.inspect}"
      puts "  fname               : #{fname.inspect}"
      puts "  @file_reg_db[fname] : #{@file_reg_db[fname].inspect}" if @file_reg_db
    end

    return nil unless @file_reg_db && @file_reg_db[fname] && @file_reg_db[fname].ok

    range = fileparts[:key_range]
    nsheets_capture = range == KEY_RANGE_NONE ? 0 : range.end - range.begin + 1

    # 2x Day Sheet; 1x Trip File
    npages_extra = @file_reg_db[fname].num_sheets_front * 2 + @file_reg_db[fname].num_sheets_back
    nsheets_capture * 2 + npages_extra - @file_reg_db[fname].num_keys_missing * 2
  end

  ############################################################################
  # For each file, list the actual and expected number of pages (using
  # the least amount of info from the register as possible)
  def create_num_pages_report_from_file_register
    puts "Creating number-of-pages CSV file from file-register (#{File.basename(FNAME_NUM_PAGES_FILE_REG_CSV)}) ..."
    load_file_reg_db
    File.open(FNAME_NUM_PAGES_FILE_REG_CSV, 'w'){|fh|
      ## filename,actual_npages,expected_npages,comment
      fh.puts "filename,actual_npages,expected_npages,comment"	# CSV header line
      if @file_reg_db
        @fileparts_list.each{|p|
          fpath = "#{IN_SCAN_DIR}/#{p[:whole]}"
          npages = get_pdf_npages(fpath)
          npages_expected = get_expected_npages_from_file_register(p)
          comment = !npages ? "Unable to read number of pages from PDF" : (
            !npages_expected ? "Insufficient info in file-register to calculate expected pages" : (
              npages != npages_expected ? "Unexpected number of pages" : ""
            )
          )
          fh.puts "%s,%s,%s,%s" % [
            p[:whole],
            npages.to_s,
            npages_expected.to_s,
            comment
          ]
        }

      else
        fh.puts ",,,\"ERROR: File register '#{File.basename(IN_FNAME_REG_CSV)}' not found.\""
      end
    }
  end

  ############################################################################
  # Prepare data by sorted trip number
  def prepare_data_by_sorted_trip
    files_by_trip = {}
    [@fileparts_list, @fileparts_no_keys_list].each{|list|
      list.each{|parts|
        files_by_trip[ parts[:trip_s] ]  ||= []
        files_by_trip[ parts[:trip_s] ] << parts[:whole]
      }
    }

    # Sorted array (which behaves like a hash)
    @files_by_sorted_trip = files_by_trip.sort{|a,b|
      a[0].to_i == b[0].to_i ?  a[0] <=> b[0] : a[0].to_i <=> b[0].to_i
    }
  end

  ############################################################################
  # List files where trip numbers have been duplicated
  def create_trip_dup_report
    puts "Creating trip-duplicate report (#{File.basename(FNAME_TRIP_DUP_CSV)}) ..."

    File.open(FNAME_TRIP_DUP_CSV, 'w'){|fh|
      fh.puts "trip,files_with_duplicate_trip"	# CSV header line

      @files_by_sorted_trip.each{|trip,list|
        next unless list.length > 1
        fh.puts "#{trip},#{list.join("|")}"	# CSV data line
      }
    }
  end

  ############################################################################
  # List gaps in trip number
  def create_trip_gap_report
    puts "Creating trip-gap report (#{File.basename(FNAME_TRIP_GAP_CSV)}) ..."

    File.open(FNAME_TRIP_GAP_CSV, 'w'){|fh|
      fh.puts "trip_begin,trip_end,gap_status"	# CSV header line

      prev_itrip = nil
      @files_by_sorted_trip.each_with_index{|(trip,list),i|
        itrip = trip.to_i			# Extract integer prefix

        if i == 0 
          if itrip > TRIP_RANGE.begin
            fh.puts "%d,%d,%s" % [TRIP_RANGE.begin, itrip-1, TYPE_S[:gap]]	# CSV data line
          end

        elsif itrip == prev_itrip
          next

        elsif itrip != prev_itrip+1
          fh.puts "%d,%d,%s" % [prev_itrip+1, itrip-1, TYPE_S[:gap]]		# CSV data line
        end
        prev_itrip = itrip
      }
      if prev_itrip && prev_itrip < TRIP_RANGE.end
        fh.puts "%d,%d,%s" % [prev_itrip+1, TRIP_RANGE.end, TYPE_S[:gap]]	# CSV data line
      end
    }
  end

  ############################################################################
  def self.main
    puts "Process all scanned files"
    puts "========================="

    f = ScannedFilesProcessor.new
    f.collect_target_filenames
    f.collect_target_fileparts
    f.sort_by_key
    f.create_key_csv

    f.create_key_overlap_report
    f.create_key_gap_report
    f.create_no_keys_report

    f.prepare_data_by_sorted_trip
    f.create_trip_dup_report
    f.create_trip_gap_report

    #f.create_num_pages_report
    #f.create_num_pages_report(:expected)
    f.create_num_pages_report_from_file_register
  end
end

##############################################################################
# Main()
##############################################################################
ScannedFilesProcessor.main

