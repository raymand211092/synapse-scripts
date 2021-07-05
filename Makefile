all: install

install:
    install -m 755 synapse-compress.sh /usr/local/bin/synapse-compress.sh
    install -m 755 synapse-purge.sh /usr/local/bin/synapse-purge.sh

uninstall:
    rm /usr/local/bin/synapse-compress.sh
    rm /usr/local/bin/synapse-purge.sh
