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
# Filename format example "slls_d19841031_t114_k1710-1754.pdf"
# where "19841031" is the date (YYYYMMDD) and "1710" is the start-key.
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
	COMPARE KEY AND DATE ORDER

	The output below compares the following lists of PDF filenames:
	- sorted numerically by key then date (in the left column)
	- sorted numerically by date then key (in the right column)

	With the exception of files which contain no capture sheets
	(ie. filenames ending with "_k0-0.pdf") it is expected that
	the order of both columns is identical.

	Report A shows only column *differences* in context (ie. surrounded
	by other sorted filename lines).
	- Lines starting with "+" should be added to the left-column to
	  make it the same as the right-column.
	- Lines starting with "-" should be removed from the left-column
	  to make it the same as the right-column.

	Report B shows both sorted lists (in full) side by side.

EO_MSG

  dir=`dirname $0`
  flist=`ls -1 $dir/../src/*.pdf |
    sed '
      s!^.*/!!
      s!-!_!
    ' |
    sort -t_ -k4.2n,4 -k2.2n,2
  `
  list1="<(echo \"\$flist\" |sed -r 's!(.*)_!\1-!')"
  list2="<(echo \"\$flist\" |sort -t_ -k2.2n,2 -k4.2n,4 |sed -r 's!(.*)_!\1-!')"

  echo "~~~ REPORT A ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cmd="diff -U2 $list1 $list2"
  eval $cmd
  echo
  echo "~~~ REPORT B ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  cmd="diff -y -W80 $list1 $list2"
  eval $cmd

} | sed 's!$!\r!'

