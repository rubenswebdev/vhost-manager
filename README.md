# vhost-manager
A bash script to managet Vhost on Apache 2 linux

# usage

#First install script

```sh
$ ./vhost.bash install

```

#To add a virtual host call 'mysite.dev' with webroot '~/projects/mysite/web'

```sh
$ vhost -d '~/projects/mysite/web' -url mysite.dev mysite

```

#To remove a virtual host use

```sh
$ vhost -rm mysite

```

#To see help
```sh
$ vhost -h
```
