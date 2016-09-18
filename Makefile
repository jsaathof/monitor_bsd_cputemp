PODSELECT=/usr/local/bin/podselect

readme:
	$(PODSELECT) monitor_bsd_cputemp.pl > README.pod

all:
	readme
