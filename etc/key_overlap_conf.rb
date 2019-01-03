#
# Copyright (c) 2018-2019, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Manually entered data structure about keys which have been duplicated

module KeyOverlapConfig
  MSG_MULTI_FILE = "Duplicated across 2 files"	# Is directly detected by software
  MSG_SAME_FILE  = "Duplicated in same file"	# Cannot be directly detected by software

  DUP_KEYS = {
    # Key is duplicated across multiple files
    4989 => {
      :fnames  => %w{slls_d19861010_t250_k4965-4989.pdf slls_d19861013_t251_k4989-5009.pdf},
      :comment => MSG_MULTI_FILE,
    },
    22220 => {
      :fnames  => %w{slls_d19940911_t931_k22195-22220.pdf slls_d19940912_t932_k22220-22223.pdf},
      :comment => MSG_MULTI_FILE,
    },
    37735 => {
      :fnames  => %w{slls_d20020103_t1588a_k37735-37735.pdf slls_d20020819_t1587a_k37735-37755.pdf},
      :comment => MSG_MULTI_FILE,
    },
    52824 => {
      :fnames  => %w{slls_d20120910_t1_k52797-52824.pdf slls_d20120917_t2_k52824-52834.pdf},
      :comment => MSG_MULTI_FILE,
    },


    # Key is duplicated within same file
    26458 => {
      :fnames  => %w{slls_d19961008_t1132_k26443-26487.pdf},
      :comment => MSG_SAME_FILE,
    },
    51413 => {
      :fnames  => %w{slls_d20101108_t9_k51385-51417.pdf},
      :comment => MSG_SAME_FILE,
    },
  }
end

