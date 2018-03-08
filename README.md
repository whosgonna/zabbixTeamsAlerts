# zabbixTeamsAlerts
Send notifications from Zabbix to MS Teams

# Set Up A Webhook For A Teams Channel
There are many resources on the internet for how to do this.  TODO:  Get some better instructions here.

# Configuration
Enter your Teams Channel's url and your zabbix credentials in the conf/local_zabbixTeamsAlerts.yaml file. 
If desired, the colors for the alerts can be changed. They are set at the zabbix defaults as is.

It is also possible to set some things like logging parameters (though the script doesn't write much for logs anyhow).  
These should be documented.

#Installation
Install this on a server where Zabbix can execute it.  The easiest example is to put it on the Zabbix server itself. 
The following Perl modules are required, and can all be installed from cpan:

- Getopt::Long
- File::Basename
- FindBin
- Hash::Merge
- Log::Log4perl
- Config::Any
- Pod::Usage
- LWP::UserAgent
- JSON
- Zabbix::Tiny

# Configuration
Create an action in zabbix that runs the script with an argument of ```-t "{TRIGGER.ID}"```

<img src="https://i.imgur.com/FzgYDRv.png" width="600" />

# TODO:
Many things...
