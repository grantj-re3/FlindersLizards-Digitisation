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
  IN_SCAN_DIR     = "#{TOP_DIR}/src"
  OUT_DIR         = "#{TOP_DIR}/results"

  FNAME_KEYS_CSV        = "#{OUT_DIR}/keys.csv"
  FNAME_KEY_OVERLAP_CSV = "#{OUT_DIR}/key_overlap.csv"
  FNAME_KEY_GAP_CSV     = "#{OUT_DIR}/key_gap.csv"
  FNAME_NO_KEYS_CSV     = "#{OUT_DIR}/no_keys.csv"
  FNAME_NUM_PAGES_CSV   = "#{OUT_DIR}/num_pages.csv"
end

