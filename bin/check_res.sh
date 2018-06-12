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

##############################################################################
get_res_status() {
  info="$1"

  echo "$info" |grep -q -P " size = \d+ x \d+$" && {
    status=`
      echo "$info" |
        sed 's!^.* size = !!; s! x ! !' |
        ruby -ane '
          MAX_ERROR_PERCENT = 5
          NOM_RES = [7016, 4961]		# Nominal resolution

          def isWithinPct(val, nom_val)
            return nil if nom_val.to_i == 0	# Invalid resolution
            ((val.to_f / nom_val.to_i - 1) * 100).abs <= MAX_ERROR_PERCENT
          end

          # Main
          if isWithinPct($F[0], NOM_RES[0]) && isWithinPct($F[1], NOM_RES[1])
            puts "-"
          else
            puts "BadRes"
          end
        '
    `
  } || {
    status="ResInfoNotFound"
  }
}

##############################################################################
# Main
##############################################################################
[ -f  "$fname_img" ] && rm -f "$fname_img"

printf "$fmt" "Filename" $delim "Status" $delim "ImageInfo" 	# CSV header line
for f in `dirname $0`/../src/*.pdf; do
  # Extract first image from PDF; get resolution of the image
  info=`pdfimages -f 1 -l 1 $f "$rootname_img" && file "$fname_img"`
  [ -f  "$fname_img" ] && rm -f "$fname_img"

  get_res_status "$info"

  # RFC 4180 says a double quote "must be escaped by preceding it with another double quote"
  [ "$use_quote" ] && csv_info=`echo "$info" |sed 's!"!""!g'` || csv_info="$info"

  printf "$fmt" "`basename $f`" $delim $status $delim "$csv_info"	# CSV data line
done

