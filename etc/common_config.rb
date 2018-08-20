#
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Common config vars for ruby (and sh/bash)

module CommonConfig
  # Process files from MIN_FILE_COUNT  to MAX_FILE_COUNT inclusive
  MIN_FILE_COUNT = 1
  MAX_FILE_COUNT = 99999

  TOP_DIR = File.expand_path("..", File.dirname(__FILE__))	# Top level dir

  # Directories, files, file extensions, file globs, etc
  IN_SCAN_DIR      = "#{TOP_DIR}/src"
  IN_FNAME_REG_CSV = "#{IN_SCAN_DIR}/csv/Lizard_file_name_register.csv"
  OUT_DIR          = "#{TOP_DIR}/results"

  FNAME_KEYS_CSV        = "#{OUT_DIR}/keys.csv"
  FNAME_KEY_OVERLAP_CSV = "#{OUT_DIR}/key_overlap.csv"
  FNAME_KEY_GAP_CSV     = "#{OUT_DIR}/key_gap.csv"
  FNAME_NO_KEYS_CSV     = "#{OUT_DIR}/no_keys.csv"
  FNAME_TRIP_DUP_CSV    = "#{OUT_DIR}/trip_dup.csv"
  FNAME_TRIP_GAP_CSV    = "#{OUT_DIR}/trip_gap.csv"
  FNAME_NUM_PAGES_EXPECTED_CSV   = "#{OUT_DIR}/num_pages_expected.csv"
  FNAME_NUM_PAGES_ACTUAL_CSV     = "#{OUT_DIR}/num_pages_actual.csv"
  FNAME_NUM_PAGES_FILE_REG_CSV   = "#{OUT_DIR}/num_pages_file_reg.csv"
end

