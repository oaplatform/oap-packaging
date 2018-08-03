#uninstall
if [ $1 -eq 0 ]
then
    systemctl stop SERVICE || true
fi
