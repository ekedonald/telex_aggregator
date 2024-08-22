# Telex Aggregator

An app that monitors logs in files and directories and sends them to a Telex Webhook.

## Installing

You can install the app with the following command:

```sh
wget  https://raw.githubusercontent.com/vicradon/telex_aggregator/main/install.sh
bash install.sh
```

Or

```sh
bash <(curl -s https://raw.githubusercontent.com/vicradon/telex_aggregator/main/install.sh)
```

Then you'll add your Webhook URL as per the prompt, the application name, and the directory you will like to watch.

```
Enter Webhook URLs (separate multiple URLs with space): https://ping.staging.telex.im/api/v1/webhooks/feed/e80dklioc
Enter Application name: Kimiko Backend Logs
Enter Log Directory Paths (separate multiple paths with space): /home/$USER/telex_be/logs/app.log
```

## Running

The application runs as a systemd service in the background and sends logs when new logs come. You can configure the interval by modifying the `interval` field on the config file. The default is 30 seconds. This is the default config file content:

```
clients:
  - webhook_urls:
      - https://ping.staging.telex.im/api/v1/webhooks/feed/389iodjdu9

targets:
  - application: Telex Backend Logs
    paths:
      - /home/someguy/telex_be/logs/app.log

interval: 30s
```

## Uninstalling

The script `./uninstall_telex.sh` will run the opposite of the install script and remove the application binary, the sqlite database, and the config file.

## Contributing

Errm...

## LICENSE

MIT
