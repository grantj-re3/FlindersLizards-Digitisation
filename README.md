# FlindersLizards-Digitisation

Tools to support the digitisation of lizard day sheets, capture sheets and trip files.

## check_key_date_order.sh

This script attempts to confirm that the date-order and key-order both
increase together. The intention is to find filename typing mistakes in
one of these two fields. Results are written to STDOUT. Common usage is:

```
  cd results
  ../bin/check_key_date_order.sh > check_key_date_order.diff.txt
```

## check_res.sh

This script attempts to extract the first image from each PDF and confirm
the resolution of the scanned image is within reasonable limits. The results
are in CSV format and are written to STDOUT. Common usage is:

```
  cd results
  ../bin/check_res.sh > check_res.csv
```

## process_scanned_files.rb

The purpose of this script is to produce a variety of spreadsheet reports
regarding the digitised files.

The keys.csv spreadsheet is information to be merged into
the researchers' Excel spreadsheet with the VLOOKUP function or similar.
The keys.csv will be invalid if there are any duplicate keys (as the same
key will appear more than once in the key/lookup column).

The other reports highlight potential issues for further investigation.
- key_gap.csv
- key_overlap.csv
- num_pages_file_reg.csv
- trip_dup.csv
- trip_gap.csv

Files key_gap.csv, key_overlap.csv, trip_dup.csv and trip_gap.csv
use *only* the PDF filenames (which encode date, trip and key info)
to produce the report. To produce the num_pages_file_reg.csv report,
the program also needs to:
- read the number of pages within the PDF to give the actual_npages
  column
- read a CSV file-register (which is a single document with one row
  of information per PDF) in order to calculate the expected_npages
  column

### Usage

After confirming you are happy with the configuration in
etc/common_config.rb, have copied scan files into the src
folder and have copied the CSV file-register to
src/csv/Lizard_file_name_register.csv, the usage is:

```
  cd results
  ../bin/process_scanned_files.rb
```

### Scanned filenames

Scanned filenames have the following format.
```
slls_dYYYYMMDD_tTRIPNO_kKEYBEGIN-KEYEND.EXT
Eg. slls_d19860930_t241_k4794-4802.pdf
```

If there are no capture sheets, KEYBEGIN and KEYEND shall both be zero.
```
Eg. slls_d19860930_t241_k0-0.pdf
```

## Environment

- Red Hat Enterprise Linux Server release 6.10
- ruby 1.8.7
- bash 4.1.2(1)-release

