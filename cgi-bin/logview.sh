#!/bin/sh
echo "Content-Type: application/json"
echo ""

logread | tail -n 50 | awk '
BEGIN {
  print "["
}
{
  gsub("\"", "\\\"", $0);  # escape dấu "
  printf "%s{\"line\": \"%s\"}", (NR==1?"":","), $0
}
END {
  print "\n]"
}
'
