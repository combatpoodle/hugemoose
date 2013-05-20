# HUGEMOOSE

HugeMoose is your very best friend.  He reads incoming application and server configurations sent by ImaginarySquid through Hubot, runs them through your validation and templates, then saves them magically in the right spot!

This keeps your application's configuration spic and span during scaling and migrations.  Yay!

There are some cool things you can do with external validators as well - moving configs around by analyzing load and weighting the results, etc.  If you do something like this and find your servers are switching over every 15 seconds, that's simply the result of failing to add damping factors and some history into the equation.  Refer to the damped harmonic oscillator physics problem for help.

### Scenario 1:
##### MySQL with multiple masters and slaves.

We want to give priority to masters that are in our datacenter but fall back to any other datacenter if there are none available here.  Slaves are picked such that they match with the master we pick in case there are (supposedly online) slaves attached to an offline master.

Config sample, defines a mysql service, configuration input/output, and some properties.
```
{
	"templates": {
		"mysql": {
			"/tmp/ServerConfig-out.php": "/tmp/ServerConfig-in.php"
		}
	},
	"services": {
		"mysql": {
			"available_handlers": {
				"1.2.3.4": {
					"database": "asdfghjkl",
					"host": "1.2.3.4",
					"port": "13306",
					"write": true,
					"datacenter": "us-east-1a"
				},
				"4.5.6.7": {
					"database": "asdlkfj",
					"host": "4.5.6.7",
					"port": "13306",
					"write": true,
					"datacenter": "us-west-1b"
				},
				"1.2.3.5": {
					"database": "asldkfj",
					"host": "1.2.3.5",
					"port": "234567",
					"write": false,
					"master": "1.2.3.4",
					"datacenter": "us-east-1a"
				}
			}
		}
	},
	"datacenter": "us-east-1a"
}
```

Template sample:
```
$db_write_hosts = [
	{%- for handler in all_handlers %}
		{%- if handler.write and handler.datacenter == configuration.datacenter %}
			'{{handler.host}}'
		{%- endif %}
	{%- endfor %}
];

if (! $db_write_hosts ) {
	$db_write_hosts = [
		{%- for handler in all_handlers %}
			{%- if handler.write %}
				'{{handler.host}}',
			{%- endif %}
		{%- endfor %}
	];
}

$db_read_hosts = [
	{%- for write_handler in all_handlers %}
		{%- if write_handler.write %}
			'{{write_handler.host}}' => [
				{%- for handler in all_handlers %}
					{%- if not handler.write %}
						{%- if handler.master == write_handler.host %}
							'{{handler.host}}',
						{%- endif %}
					{%- endif %}
				{%- endfor %}
			],
		{%- endif %}
	{%- endfor %}
];

$db_write_host = $db_write_hosts[ array_rand( $db_write_hosts ) ];

if ( empty( $db_read_hosts[ $db_write_host ] ) ) {
	$db_read_host = $db_write_host;
} else {
	$db_read_hosts = $db_read_hosts[ $db_write_host ];

	$db_read_host = $db_read_hosts[ array_rand( $db_read_hosts ) ];
}
```

This outputs the following:
```
$db_write_hosts = [
			'1.2.3.4',
];

$db_read_hosts = [
			'1.2.3.4' => [
							'1.2.3.5',
			],
];

$db_write_host = $db_write_hosts[ array_rand( $db_write_hosts ) ];

if ( empty( $db_read_hosts[ $db_write_host ] ) ) {
	$db_read_host = $db_write_host;
} else {
	$db_read_hosts = $db_read_hosts[ $db_write_host ];

	$db_read_host = $db_read_hosts[ array_rand( $db_read_hosts ) ];
}
```


After running `hubot hugemoose down 1.2.3.4`, we have this in our config:
```php
<?php

/**
 * Define DocBlock
 **/

$db_write_hosts = [
];

if (! $db_write_hosts ) {
	$db_write_hosts = [
				'4.5.6.7',
	];
}

$db_read_hosts = [
			'4.5.6.7' => [
			],
];

$db_write_host = $db_write_hosts[ array_rand( $db_write_hosts ) ];

if ( empty( $db_read_hosts[ $db_write_host ] ) ) {
	$db_read_host = $db_write_host;
} else {
	$db_read_hosts = $db_read_hosts[ $db_write_host ];

	$db_read_host = $db_read_hosts[ array_rand( $db_read_hosts ) ];
}
```


Then if we run `hubot hugemoose alive 1.2.3.4 mysql {"host": "1.2.3.4"}` - note the missing `write: true`, we get this in our config:
```php
<?php

/**
 * Define DocBlock
 **/

$db_write_hosts = [
];

if (! $db_write_hosts ) {
	$db_write_hosts = [
				'4.5.6.7',
	];
}

$db_read_hosts = [
			'4.5.6.7' => [
			],
];

$db_write_host = $db_write_hosts[ array_rand( $db_write_hosts ) ];

if ( empty( $db_read_hosts[ $db_write_host ] ) ) {
	$db_read_host = $db_write_host;
} else {
	$db_read_hosts = $db_read_hosts[ $db_write_host ];

	$db_read_host = $db_read_hosts[ array_rand( $db_read_hosts ) ];
}
```


Finally, we run a working configuration through it: `hubot hugemoose alive 1.2.3.4 mysql {"host": "1.2.3.4", "write": true}`

```php
<?php

/**
 * Define DocBlock
 **/

$db_write_hosts = [
];

if (! $db_write_hosts ) {
	$db_write_hosts = [
				'1.2.3.4'
				'4.5.6.7'
	];
}

$db_read_hosts = [
			'1.2.3.4' => [
							'1.2.3.5'
			]
			'4.5.6.7' => [
			]
];

$db_write_host = $db_write_hosts[ array_rand( $db_write_hosts ) ];

if ( empty( $db_read_hosts[ $db_write_host ] ) ) {
	$db_read_host = $db_write_host;
} else {
	$db_read_hosts = $db_read_hosts[ $db_write_host ];

	$db_read_host = $db_read_hosts[ array_rand( $db_read_hosts ) ];
}
```

We're now back to where we started!




