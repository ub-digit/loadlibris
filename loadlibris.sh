#!/bin/bash
base_dir="/home/koha/loadlibris"
koha_user="koha"
koha_shell_bin="$base_dir/koha-shell"
#in_dir="$base_dir/in"
in_dir="/home/koha/librload/in"
in_archive_dir="$base_dir/in_archive"
adjustlibris_err_dir="$base_dir/adjustlibris_err"
adjustlibris_bin="/home/koha/adjustlibris/main.rb"

bulkmarcimport_in_dir="$base_dir/bulkmarcimport_in"
bulkmarcimport_err_dir="$base_dir/bulkmarcimport_err"
bulkmarcimport_log_file="/var/log/bulkmarcimport"

koha_base_dir="/home/koha/koha-lab/current"
koha_instance="koha"
bulkmarcimport_bin="$koha_base_dir/misc/migration_tools/bulkmarcimport.pl"
bulkmarcimport_to_marc_plugin="Koha::Plugin::Se::Ub::Gu::MarcImport"
bulkmarcimport_match="System-control-number,035a"

done_dir="$base_dir/done"

function log_error {
  logger -s -p syslog.err "$1" 2>> /var/log/loadlibris
}

function log_info {
  logger -s -p syslog.info "$1" 2>> /var/log/loadlibris
}

for filepath in $(find "$in_dir" -name '*.marc' | sort); do
  filename=$(basename "$filepath")
  errors=$(sudo -u $koha_user bash -c "source \$HOME/.rvm/scripts/rvm && cd /home/koha/adjustlibris && ./main.rb \"$filepath\" \"$bulkmarcimport_in_dir/$filename\" 2>&1")
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
  errors=$($koha_shell_bin -c /home/koha/koha-lab/current/misc/migration_tools/bulkmarcimport.pl\ -b\ -file\ \"$filepath\"\ -insert\ -update\ -c\=MARC21\ -match\=\"System-control-number,035a\"\ -tomarcplugin\ \"Koha::Plugin::Se::Ub::Gu::MarcImport\" $koha_instance 2>&1 1>/dev/null)
  if [ $? -eq 0 ]; then
    log_info "bulkmarcimport successfully processed \"$filename\""
    mv "$filepath" "$done_dir/"
  else
    log_error "bulkmarcimport on file \"$bulkmarcimport_err_dir/$filename\" failed with exit status $?"
    mv "$filepath" "$bulkmarcimport_err_dir/$filename"
    echo "$errors" > "$bulkmarcimport_err_dir/${filename}.err"
  fi
done
