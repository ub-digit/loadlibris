#!/bin/bash
script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/loadlibris.sh.conf"

koha_shell_bin="$script_dir/koha-shell"

function log_error {
  logger -s -p syslog.err "$1" 2>> "$loadlibris_log_dir/loadlibris"
}

function log_info {
  logger -s -p syslog.info "$1" 2>> "$loadlibris_log_dir/loadlibris"
}

for filepath in $(find "$fetchlibris_done_dir" -name '*.marc' | sort); do
  # Archive all incoming files
  cp "$filepath" "$bulkmarcimport_in_archive_dir/"
  mv "$filepath" "$bulkmarcimport_in_dir/"
done

for filepath in $(find "$bulkmarcimport_in_dir" -name '*.marc' | sort); do
  filename=$(basename "$filepath")
  output=$($koha_shell_bin -c $koha_path/misc/migration_tools/bulkmarcimport.pl\ -b\ -file\ \"$filepath\"\ -l=\"$loadlibris_log_dir/bulkmarcimport.log\"\ -append\ -match_record_id\ -insert\ -update\ -c\=MARC21\ -tomarcplugin\ \"Koha::Plugin::Se::Ub::Gu::MarcImport\" $koha_instance 2>&1)
  if [ $? -eq 0 ]; then
    log_info "bulkmarcimport successfully processed \"$filename\""
    echo "$output\n\n" >> "$loadlibris_log_dir/bulkmarcimport.output"
    mv "$filepath" "$bulkmarcimport_done_dir/"
  else
    log_error "bulkmarcimport on file \"$bulkmarcimport_err_dir/$filename\" failed with exit status $?"
    mv "$filepath" "$bulkmarcimport_err_dir/$filename"
    echo "$output" > "$bulkmarcimport_err_dir/${filename}.err"
  fi
done
