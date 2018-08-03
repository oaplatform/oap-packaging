
if [ ! "unknown" = `systemctl is-active SERVICE` ]
then
    if [ "disabled" = `systemctl is-enabled SERVICE` ]
    then
        systemctl enable SERVICE
    fi

    if [ "active" = `systemctl is-active SERVICE` ]
    then
        systemctl restart SERVICE
    else
        systemctl start SERVICE
    fi
fi
