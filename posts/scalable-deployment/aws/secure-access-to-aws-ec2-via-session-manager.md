---
title: Secure Access to AWS EC2 via SSH over Session Manager
published: false
description:
tags:
# cover_image: https://direct_url_to_image.jpg
# Use a ratio of 100:42 for best results.
# published_at: 2024-09-14 23:53 +0000
---

It use to be the only way to access EC2 instances remotely using ssh required setting up Bastion instances with public IP / ports open to the Internet or even worse, having public IP / Ports open on your EC2 instances. Or you could set up some kind of VPN but that too required significant undiferrentiated heavy lifting.

AWS introduces the [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) a while ago, but I  still see many teams using old school ssh with open ports, white lists and Bastion hosts. Its past time to stop doing that and take advantage of Session Manager.

Session Manager enables:
* No Open Ports or Public IP addresses
* No need to white list IPs to protect your ports
* Leverage AWS IAM and SSO to gain access to your EC2 instances instead of passwords and keys
* Login activity and usage logged to Cloudwatch
* You can still use SSH for terminal access and set up SSH tunnels over Session Manager

You can open a Session Manager session to an EC2 instance via the AWS EC2 console, but that gives you a terminal in a Web Browser window. And its a pretty lousy terminal without all the comfort and customization you might have in your native terminal windows that you are use to from ssh'ing in traditionally.

Here we're going to show how to ssh over Session Manager connections so you get all the advantages of Session Manager and you can stay in your comfy native terminal environments.

## AWS Prerequisites

It is beyond the scope of this article to go into the details of setting up all the prerequisites. If you are already using a recent version of the AWS CLI on your local workstation and your EC2 instances are running relatively recent versions of Amazon Linux or other official AWS mainstream AMIs you probably have most of this already.

But do review the following to make sure.

- Have to use a [supported machine type / OS](https://docs.aws.amazon.com/systems-manager/latest/userguide/operating-systems-and-machine-types.html)
    - Current Amazon Linux, Windows and Mac OS are supported
- AWS Systems Manager SSM Agent version 2.3.68.0 or later must be installed on the managed nodes you want to connect to through sessions.
    - Ideally should have  SSM Agent version 3.0.284.0 or later to get all the features available
    - Amazon Linux based instances usually have some version installed already
    - [How to verify the status of SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html#verify-ssm-agent-status)
- The managed nodes you connect to must allow HTTPS (port 443) outbound traffic to at least the following endpoints:
    - `ec2messages.region.amazonaws.com`
    - `ssm.region.amazonaws.com`
    - `ssmmessages.region.amazonaws.com`


## Setup your local workstation

These are the steps you need to do on your local workstation that you will use to access the remote EC2 instances. The following is known to work on macOS and probably Linux for the most part.

### Install AWS CLI & Session Manager plugin

- [Getting started with the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
- [Install the Session Manager plugin for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [Setting up the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)
    - Mainly making sure you have your IAM or IAM Identity Center credentials set up right
- Ensure your EC2 instance role has the AWS-provided default policy `AmazonSSMManagedInstanceCore` attached
    - Or if you need something more tuned you can follow [Step 2: Verify or add instance permissions for Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-instance-profile.html) in the __Setting up Session Manager Guide_
- Ensure the IAM role of yourself or whatever users that will be using the Session Manager has proper IAM permissions


### Set up your local ~/.ssh/config

To make it easy to ssh into any ec2 instance by instance id you can do this:

- Copy the following to your `.ssh/config`:
  ```
  # SSH over Session Manager
  Host i-* mi-*
    ProxyCommand sh -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
  ```
You could ether or also create specific aliases so you can refer to the instances by name instead of  instance-id

- Will need one per instance if you want to do this way
- The Host key can be anything, doesn't have to be the actual name of the instance
    - In this example its `my-instance`
- Replace `i-1f10adafc1a128691a` with the instance id of the machine you want
  ```
  Host my-instance
    ProxyCommand sh -c "aws ssm start-session --target i-1f10adafc1a128691a --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
  ```

### Generate the ssh key in your local terminal / shell

If you don't already have a public ssh key in the target machine, create a private / public key for this

- Make the key's filename and comment be the same so you can keep track of the keys once they are deployed
    - Use some form of naming convention to  have some consistency
    - Our example is using `<your-username>-<env>-<machine-name>`
- Ideally make a key per environment if not per machine
    - Similar to not wanting to have the same key used in multiple places in case your key gets compromised, only impacts one machine
- Make sure you create an ssh key that has a password
    - Use 1Password or other secrets manager to create/store the password for the key
    - Create a password with the secret manager or other technique that generates a strong password and stores it in a safe place that you can easily use
    [![Canonical XKCD Password Strength Explanation]( https://imgs.xkcd.com/comics/password_strength.png)](https://xkcd.com/936/)

Command usage:
```shell
ssh-keygen -t ed25519 -C "<your-username>-<env>-<machine-name>"
```

- Example of creating an ssh key in the terminal shell:
    ```
    > ssh-keygen -t ed25519 -C "rob.berger-my-instance"
    Generating public/private ed25519 key pair.
    Enter file in which to save the key (/Users/rberger/.ssh/id_ed25519): ~/.ssh/rob.berger-my-instance
    Enter passphrase (empty for no passphrase): <Password created in 1Password>
    Enter same passphrase again: <Password created in 1Password>
    <output of keygen>
    ```

## Use the Session Manager to copy key to target EC2 instance

You can use AWS Session Manager directly or any other way you can log into the machine to update the appropriate `~/.ssh/authorized_keys` file

The following assumes you have established a credentialed session via `aws sso` or have your `~/.aws/config` setup for IAM access to the account your EC2 instance is residing in. And that you have the `AWS_PROFILE` or appropriate Shell Environment variables [set up correctly to use the aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html)

- The form of the command is:
  ```
  aws ssm start-session --target <instance-id>
  ```

- Example  login into the my-instance instance-id: ` i-1f10adafc1a128691a` in prod (assumes you are sso'd in to aws)
  ```
  aws ssm start-session --target  i-1f10adafc1a128691a
  ```

- This will log you in as the `ssm-user` you could add the key here if you want to ssh in as the ssm-user, but you should ssh in as ec2-user if you are the only user and you want sudo access. Or better yet create and use some other user.
    - If you are logged in as the ssm-user you will see something like:
      ```
      Starting session with SessionId: rob.berger@informed.iq-qpjr22iwibpop33veqfxbmi62m
      sh-4.2$
      ```

    - You will need to become the user you want to update
        - Use sudo su to do that:
        ```
        > sudo su - ec2-user
        Last login: Wed Sep  4 05:12:49 UTC 2024 from localhost on pts/110
        [ec2-user@ip-20-40-0-202 ~]$
        ```

        - You can then use an editor to update `~ec2-user/.ssh/authorized_keys` with your public key
            - Make sure not to delete or mess up any other keys in there
            - Make sure that both `~ec2-user/.ssh/` and `~ec2-user/.ssh/authorized_keys` are  owned by and can only be accessed by `ec2-user`
              ```
              chown ec2-user ~ec2-user/.ssh ec2-user/.ssh/authorized_keys
              chmod og-rw ~ec2-user/.ssh ec2-user/.ssh/authorized_keys
              ```


### Mechanisms to not have to type your SSH Key password
- If you do one  of these options, you will not have to specify the ssh key on the ssh command line or enter the password for your ssh key each time you ssh into an ec2 instance.

### Using the ssh-agent
- This assumes you are on a Mac. It works similarly if you are on Linux but not quite the same
- You should only need to do this once. It will both add it to the agent and store it in the Apple Keychain
  ```
  ssh-add --apple-use-keychain ~/.ssh/rob.berger-my-instance
  ```
- Then the first time you want to use this key after you have rebooted your laptop you will need to run:
  ```
  ssh-add --apple-load-keychain
  ```
    - This will load all keys you have stored in your keychange
- Using 1Password
    - You can setup 1password to do all this for you if you have 1password installed on your laptap (You really should!)
        - If you do this you don't need to do the previous section of `Using the ssh-agent`
    - Under 1Password Settings->Developer enable
        - `Use the SSH Agent`
        - `Integrate with 1Password CLI`

## Using SSH over SSM Session Manager
- After you do all of the above you can now start to use ssh and scp type commands from your laptop
    - Remember to have sso'd in on your laptop terminal
    - You will need to set the AWS_PROFILE for your shell or for each command to be the profile for where the instance is in
    - You can then use ssh commands like:
        - If you don't export AWS_PROFILE for your shell you can specify it on the command line
        - If you didn't ssh-add the ssh key to the system or 1password ssh-agent you will have to specify it here:
          ```
          ssh -i ~/.ssh/rob.berger-my-instance  ec2-user@i-1f10adafc1a128691a
          ```

          ```
          ssh ec2-user@i-1f10adafc1a128691a
          ```

        - And of course if you already exported AWS_PROFILE and did ssh-add then it is as simple as:
          ```
          ssh ec2-user@i-1f10adafc1a128691a
          ```

- You can use any ssh style command the same way (mainly `scp`)

### Setting up SSH Tunnels
- You can set up ssh tunnels as well
- To set up a tunnel for port 8888 to access the Jupyter Notebook on the my-instance machine
  ```
  ssh -f -N -L 8888:localhost:8888 ec2-user@i-1f10adafc1a128691a
  ```

- Then you can browse to `http://localhost:8888`
- Though you don't really need this since  you can access via the ALB and https
- But you get the idea. Can be used similarly for other tunneling if you need it.
