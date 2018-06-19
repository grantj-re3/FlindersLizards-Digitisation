#!/bin/bash
# check_key_date_order.sh
#
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Look for file naming issues by comparing:
# - PDF filenames sorted by key then date, with
# - PDF filenames sorted by date then key
#
# Algorithm:
# - List all PDF basenames
# - Change hyphen ("-") after start-key into underscore delimiter ("_") for sort
# - Sort numerically by key then date
# - diff the above with same list of PDFs sorted numerically by date then key
# - Reinstate last underscore delimiter with hyphen
# - Ensure end-of-line is '\r\n' for display in Windows Notepad
#
##############################################################################
{
  cat <<-EO_MSG
	The output below compares the following lists of PDF filenames:
	- sorted numerically by key then date (on the left)
	- sorted numerically by date then key (on the right)
	It is expected that the order of both lists is identical.

EO_MSG

  dir=`dirname $0`
  flist=`ls -1 $dir/../src/*.pdf |
    sed '
      s!^.*/!!
      s!-!_!
    ' |
    sort -t_ -k4.2n,4 -k2.2n,2
  `
  diff -y \
    <(echo "$flist" |sed -r 's!(.*)_!\1-!') \
    <(echo "$flist" |sort -t_ -k2.2n,2 -k4.2n,4 |sed -r 's!(.*)_!\1-!')

} | sed 's!$!\r!'

