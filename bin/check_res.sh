#!/bin/sh
# check_res.sh
#
# Copyright (c) 2018, Flinders University, South Australia. All rights reserved.
# Contributors: Library, Corporate Services, Flinders University.
# See the accompanying LICENSE file (or http://opensource.org/licenses/BSD-3-Clause).
#
# Quick hack!
# Iterate through all PDFs:
# - Extract the image on the first page of the PDF
# - Extract the resolution of the image
# - If it is not the expected resolution (A4 @ 600dpi = 7016x4961) then show this in the status
# - Display the filename and status in a CSV-like format
#
##############################################################################
true="1"
false=""

delim=","
use_quote=$true		# If true then wrap every field in double quotes.
[ "$use_quote" ] && fmt="\"%s\"%s\"%s\"%s\"%s\"\n" || fmt="%s%s%s%s%s\n"  # printf format

rootname_img="img1"
fname_img="$rootname_img-000.ppm"
[ -f  "$fname_img" ] && rm -f "$fname_img"

printf "$fmt" "Filename" $delim "Status" $delim "ImageInfo" 	# CSV header line
for f in ../src/slls_*.pdf; do
  # Extract first image from PDF; get resolution of the image
  info=`pdfimages -f 1 -l 1 $f "$rootname_img" && file "$fname_img"`
  [ -f  "$fname_img" ] && rm -f "$fname_img"

  status="-"
  if ! echo "$info" |egrep -q " size = 7016 x 4961$"; then status="BadRes"; fi

  # RFC 4180 says a double quote "must be escaped by preceding it with another double quote"
  [ "$use_quote" ] && csv_info=`echo "$info" |sed 's!"!""!g'` || csv_info="$info"

  printf "$fmt" "`basename $f`" $delim $status $delim "$csv_info"	# CSV data line
done

