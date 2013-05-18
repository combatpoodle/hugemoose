# HUGEMOOSE

HugeMoose is your very best friend.  He reads incoming application and server configurations send by ImaginarySquid, runs them through your templates, then saves them magically in the right spot!  

This keeps your application's configuration spic and span during scaling and migrations.  Yay!

Config sample:
```
{
	'templates': {
		'mysql': {
			'/var/www/public/wp-config.php': '/etc/hugemoose.d/wp-config.php'
		}
	}
	'services': {
		'mysql': {
			'immutable_handlers': {
				'1.2.3.4': {
					'database': 'asdfghjkl',
					'host': '1.2.3.4',
					'port': '13306',
					'write': true
				}
			},
			'available_handlers': {
				'1.2.3.5': {
					'database': 'asldkfj',
					'host': '1.2.3.5',
					'port': '234567',
					'write': false
				}
			}
		},
	}
}

```