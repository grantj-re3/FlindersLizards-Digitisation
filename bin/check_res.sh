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
# - If it is not the expected resolution (A4 @ 600dpi = 7016x4961) then show file details
#
##############################################################################

for f in ../src/slls_*.pdf; do
  echo
  echo "### $f" &&
    pdfimages -f 1 -l 1 $f page1 &&
   sum page1-000.ppm &&
   file page1-000.ppm |egrep -v " size = 7016 x 4961$" # Show res if res is incorrect
done

