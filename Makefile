all: install

install: synapse-purge-compress.sh
	install -m 755 synapse-purge-compress.sh /usr/local/bin/synapse-purge-compress

uninstall:
	rm /usr/local/bin/synapse-purge-compress
