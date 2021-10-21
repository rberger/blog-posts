---

title: Set up SSL/TLS for shadow-cljs https server
menu_order: 1
post_status: publish
post_excerpt: Howto create TLS Server Certificate and use with clojurescript shadow-cljs development server

---
# Set Up SSL/TLS HTTPS for shadow-cljs Development Server

While developing clojurescript web apps, you may require that the development http server (shadow-cljs)[https://github.com/thheller/shadow-cljs] operate with SSL/TLS to serve up HTTPS, not just HTTP.

This is particuarly true if you need to test things out on an iPhone or Android phone but still run with the development server so you can iterated changes just as quick as when you are working with desktop clients.

Its a bit tricky to get everything lined up to make SSL/TLS work locally as Apple (and I presume other browsers) no longer support self-signed certificates for HTTPS servers. So you need a private CA and a certificate generated from the private CA.

This is a guide to set up:
* A Private Certificate Authority (CA)
* A Server Certificate for your shadow-cljs development server
* How to configure shadow-cljs.edn for SSL
* How to install the CA Root Certificate on other clients (like an iPhone) so they can access the shadow-cljs servers

***NOTE**: This server / CA / Certificates should never be used in production or in any particularly public way. It’s not secure. We’re doing this to get around the normal browser / server security just for local development.* 

## Install mkcert
See the following for more info or how to install on Linux: [GitHub - FiloSottile/mkcert: A simple zero-config tool to make locally trusted development certificates with any names you’d like.](https://github.com/FiloSottile/mkcert)
### Install mkcert on macOS
```
> brew install mkcert
> brew install nss # if you use Firefox
```

## Create a local CA to be used by mkcert and clients
```
> mkcert -install
Created a new local CA 💥
Sudo password:
The local CA is now installed in the system trust store! ⚡️
The local CA is now installed in the Firefox trust store (requires browser restart)! 🦊
The local CA is now installed in Java's trust store! ☕️
```
## Create a pkcs12 certificate
Easiest to do this in the directory you are running the shadow-cljs project.
Create a subdirectory `ssl` at the same level as shadow-cljs (top level of the repo usually) and cd into `ssl`
```
❯ cd ~/work/my-project
❯ ls
Makefile        RELEASE_TAG     bin             dev             package.json    shadow-cljs.edn test
README.org      amplify         deps.edn        node_modules    resources       src             yarn.lock

❯ mkdir ssl
❯ cd ssl
```

Create the certificate that the shadow-cljs servers will use as their server certificates. You want to specify all the domains and IPs that would be associated with the certificate and the way you will access the server.
In my case my iMac has two interfaces plus localhost. One interface is the Ethernet, the other is the wifi. And just to be safe, I’m putting in their IPv6 addresses as well.
```
❯ mkcert -pkcs12 discovery.local localhost  192.168.20.10 192.168.20.11 127.0.0.1 ::1 fd95:cb6f:7955:0:1878:b8b5:1b3b:ad27 fd95:cb6f:7955:0:4cd:c922:d1b3:2eb5

Created a new certificate valid for the following names 📜
 - "discovery.local"
 - "localhost"
 - "192.168.20.10"
 - "192.168.20.11"
 - "127.0.0.1"
 - "::1"
 - "fd95:cb6f:7955:0:1878:b8b5:1b3b:ad27"
 - "fd95:cb6f:7955:0:4cd:c922:d1b3:2eb5"

The PKCS#12 bundle is at "./discovery.local+7.p12" ✅

The legacy PKCS#12 encryption password is the often hardcoded default "changeit" ℹ️

It will expire on 20 January 2024 🗓
```

## Install the cert into the keystore 

___NOTE:___ *The passwords  you use here should not be used anywhere else, particularly on public services. They do not have to be super secret, great passwords as they will be in the clear in your shadow-cljs.*

You will create a local Java JKS Keystore in `ssl` to be used by shadow-cljs servers
* `Destination Password`: This will be the password specified in shadow-cljs.edn to gain access to the keystore.  Our example will be `super-secret`
* `Source keystore password`: The password that `mkcert` used to generate the Server Certificate and thus the password of the Server Certificate. I could not find a way to specify it. It defaults to `changeit`
```
❯ keytool -importkeystore -destkeystore keystore.jks -srcstoretype PKCS12 -srckeystore discovery.local+7.p12
Importing keystore discovery.local+7.p12 to keystore.jks...
Enter destination keystore password: super-secret
Re-enter new password: super-secret
Enter source keystore password: changeit
Entry for alias 1 successfully imported.
Import command completed:  1 entries successfully imported, 0 entries failed or cancelled
```

## Configure shadow-cljs.edn to enable SSL
Mainly need to add an `:ssl` coda to the start of the `shadow-cljs.edn` 

```
{:deps  true
 :nrepl {:port 8777}
 :ssl {:keystore "ssl/keystore.jks"
       :password "retold-fever"}
 :dev-http {8020 {:root "resources/public"}}
 ... rest of your shadow-cljs.edn file...
```
No need to specify the hostnames. In fact that will limit access to IP addresses that resolve to that name which may be incorrect.
More info on the `:ssl` configuration at [Shadow CLJS User’s Guide: SSL](https://shadow-cljs.github.io/docs/UsersGuide.html#_ssl)

[Re]start your shadow-cljs watch process and it should say something like the following at some point in its startup where `https` is the protocol shown for the http and shadow-cljs servers:
```
...
shadow-cljs - HTTP server available at https://localhost:8020
shadow-cljs - server version: 2.15.8 running at https://localhost:9631
shadow-cljs - nREPL server started on port 8777
shadow-cljs - watching build :app
...
```
Assuming you set the certificate to support any other domain names and IP addresses associated with your computer running this, they will also work as the host address in your client URL accessing this server. But only if running on the same machine as this server.

If you want to make another device (like an iPhone or another computer) access this server, follow the next steps.

## Export the Root CA of your Private CA to other Clients
In order for other machines on your LAN to access the shadow-cljs server running with the Private CA and Server certificate set up in the earlier steps,  you will need to export the Root CA from that machine to these other clients.
### Find the location of the Root Certificate of the Private CA
When you ran `mkcert install` it created the root certificates of the Private CA and stashed them somewhere appropriate for your system. You can find out where with the command:
```
❯ mkcert -CAROOT
/Users/rberger/Library/Application Support/mkcert

❯ ls '/Users/rberger/Library/Application Support/mkcert'
rootCA-key.pem rootCA.pem
```
You will want to copy the `rootCA.pem` to other clients that would access the shadow-cljs servers.

### For transferring to other Macs or iOS devices
```
open '/Users/rberger/Library/Application Support/mkcert'
```
Which will open a finder window with the directory where these pem files are:
![Root Cert in Finder](/_images/ssl-airdrop-root-cert.png)

And then select AirDrop to send them to other macOS or iOS devices
Otherwise you can email it or send the file some other way to a destination device.
## Install the Private CA Root Cert on iOS device
* Once you send the Cert to an iOS device, you will get a message 
![Choose Device](/_images/ssl-choose-device.png)

* Select iPhone  and then select Close:
![Select Close](/_images/ssl-profile-downloaded-close.jpg)

* Go to Settings and you’ll see the a new option `Profile Downloaded` Click on that and the go thru the rest of the dialogs agreeing to Install the downloaded profile.
 
![Profile Downloaded in Settings](/_images/_ssl-settings.jpg)

* After completing all the install dialogs, this client should be ready to connect to the shadow-cljs using https.
