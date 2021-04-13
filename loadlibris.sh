#!/bin/bash
script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/loadlibris.sh.conf"

koha_shell_bin="$script_dir/koha-shell"

# TODO: Perhaps place these in loadlibris.sh.conf?


function log_error {
  logger -s -p syslog.err "$1" 2>> "$loadlibris_log_dir"
}

function log_info {
  logger -s -p syslog.info "$1" 2>> "$loadlibris_log_dir"
}

for filepath in $(find "$in_dir" -name '*.marc' | sort); do
  filename=$(basename "$filepath")
  errors=$(sudo -u $koha_user bash -c "source \$HOME/.rvm/scripts/rvm && cd \$adjustlibris_path/adjustlibris && ./main.rb \"$filepath\" \"$bulkmarcimport_in_dir/$filename\" 2>&1")
  if [ $? -eq 0 ]; then
    log_info "ajustlibris successfully processed \"$filename\""
    mv "$filepath" "$in_archive_dir/"
  else
    log_error "adjustlibris on file \"$adjustlibris_err_dir/$filename\" failed with exit status $? and output \"$errors\""
    mv "$filepath" "$adjustlibris_err_dir/"
  fi
done

for filepath in $(find "$bulkmarcimport_in_dir" -name '*.marc' | sort); do
  filename=$(basename "$filepath")
  #TODO: Errors are thrown away here? Probably for a reason
  errors=$($koha_shell_bin -c /home/koha/koha-lab/current/misc/migration_tools/bulkmarcimport.pl\ -b\ -file\ \"$filepath\"\ -insert\ -update\ -c\=MARC21\ -tomarcplugin\ \"Koha::Plugin::Se::Ub::Gu::MarcImport\" $koha_instance 2>&1 1>/dev/null)
  if [ $? -eq 0 ]; then
    log_info "bulkmarcimport successfully processed \"$filename\""
    mv "$filepath" "$done_dir/"
  else
    log_error "bulkmarcimport on file \"$bulkmarcimport_err_dir/$filename\" failed with exit status $?"
    mv "$filepath" "$bulkmarcimport_err_dir/$filename"
    echo "$errors" > "$bulkmarcimport_err_dir/${filename}.err"
  fi
done
