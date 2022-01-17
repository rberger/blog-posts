---
title: Connect Quicksight to RDS in a private VPC
menu_order: 1
post_status: publish
tags: aws, awscommunity, quicksight
post_excerpt: How to setup a Quicksight VPC Connection to Aurora RDS in a private VPC
---

There are cases where you want to connect [AWS Quicksight](https://aws.amazon.com/quicksight/) to pull data from an RDS Database in one of your Private VPCs. Its one of those things that you don’t do often and its just funky enough and different enough from most AWS services that I have had to relearn how to do it each time. So here’s what I’ve learnt for posterity.

Quicksight can automatically connect to databases that can be accessed via a public IP. If your DB is publicly accessible to the Internet (with Security Group filtering of course), then you can pretty much ignore this article.

If you happen to have the weird case where your DB does have a public IP address but it is not actually accessible to the public Internet for policy, technical or historical reasons, then read on.

## Quicksight `VPC Connection` Requirements

Quicksight has the option of creating a connection between you instance of Quicksight and one of your VPCs. It does that by injecting a Network Interface into a subnet you specify from the target VPC.

![Networking of Quicksight and VPC](/_images/connect-quicksight-quicksight-vpc-network-interace.png)

You only have to supply the

- `VPC ID` that your target DB is in.
- `Subnet` that is routable to the subnet your target DB is in
- `Security Group` dedicated to the Quicksight connection that will allow all TCP taffic to the target DB
- Optionally a `DNS Inbound Endpoint`

We're going to assume that the target DB and its VPC already exists.

You can use an existing `Subnet` as long as its in the same VPC and is routable to the subnets used by the target DB. By default subnets in a VPC can route to any other subnet in the VPC, but you should double check.

When you create the `VPC Connection` in the Quicksight management console, it will automatically create a `Network Interface` on the specified `Subnet` and will be associated with the `Security Group` specified.

Note that the `Security Group` associated with this new Quicksight `Network Interface` will be stateless. Any response packets coming back from a Quicksight request will have randomly allocated port numbers. Normally Security groups are stateful and handle this for you. But in the case of the Quicksight Network Interface you have to explicitly enable that any port is allowed for inbound.

The optional `DNS Inbound Endpoint` allows you to tell Quicksight to use the private DNS Resolver for your VPC instead of querying just the Public DNS zones. This is what is needed if your target DB has a Public IP address. Without this setting this Quicksight will get the Public IP address when it queries the `Endpoint name` of your DB. You will be scratching your head for days wondering why the connection is not working.

If you do use `DNS Inbound Endpoint` option, you will have to set it up in `Route53`.

Detailed instructions for all of this are described below.

A `VPC Connection` will allow Quicksight to connect to any of the following in your VPC:

- Amazon OpenSearch Service
- Amazon Redshift
- Amazon Relational Database Service
- Amazon Aurora
- MariaDB
- Microsoft SQL Server
- MySQL
- Oracle
- PostgreSQL
- Presto
- Snowflake

You can reuse a `VPC Connection` for any Datasource in your Quicksight account in a region.

## Subnet Info

### Get VPC Info

We'll need the `VPC ID` and the `CIDR Block` associated

You can look at your RDS Configuration to see what VPC it is in.
![RDS Configuraiton showing VPC](/_images/connect-quicksight-rds-configuration-vpc-info.png)

In this example:

- `VPC ID` ends in `2aed`
- `CIDR Block`: 10.0.0.0/16
  ![VPC Console view of the VPC of interest](/_images/connect-quicksight-vpc-configuration.png)

### Pick a Subnet for the Quicksight Network Interface to Use

The criteria are:

- In the same VPC as the target DB
- Is a private subnet
- In the same Availability Zone as at least one of the subnets associated with the target DB
- Routable to that subnet in the target DB
  - Has a route table that routes to the VPC CIDR Block
  - And the Target DB Subnets also can route to the VPC CIDR Block
- Doesnt have an ACL that would block acces to/from the target DB
  - This is the usual case

#### Find the subnets used on the target DB

In this example our target DB is an Aurora Postgres cluster. Looking at the RDS Console we can find the subnets its usings

**Click on one of the subnets to view the subnet info**
![RDS Console with subnet info](/_images/connect-quicksight-rds-configuration.png)

**See what `Availability Zone` its in (us-east-1b in this example)**
![RDS Subnet info](/_images/connect-quicksight-rds-subnet-details-availability-zone.png)

**Confirm it routes to the VPC CIDR Block (10.0.0.0/16 in this example)**
![RDS Console showing Availability Zone](/_images/connect-quicksight-rds-subnet-details.png)

- Go to the subnet view in the VPC Console.
- Find an existing subnet that also routes to the same VPC CIDR Block (or overlapping subset with the DB subnet and its on the same `Availability Zone`)
  - You could also create a new subnet for this as long as it meets the same criteria
- In our example its the subnet that ends with `90dc`

![Existing Subnet suitable for Quicksight](/_images/connect-quicksight-quicksight-subnet.png)

## Security Group

Create a new `Security Group` dedicated to the Quicksight Network Interface. You don't _have_ to create one specific to this, but it will make management easier than trying to mix it in with your existing Security Groups.

We'll call it `Amazon-QuickSight-access`. Nothing magic about the name though, whatever fits into your naming scheme.

### Inbound Rules

Set the `Inbound Rules` to allow trafic on all TCP ports. As mentioned earlier, this is because this will be a stateless security group and all response packets will have random inbound ports.

### Outbound Rules

The `Outbound Rules` should limit the destinations to just your target DB. The easiest way is to set the destination to be the Security Group set in your RDS Database.

You should also limit the outbound ports to be ones appropriate for your target DB, such as port 5432 for Postgres.

![Outbound Rules wiht security group destination](/_images/connect-quicksight-security-group-outbound-rules.png)

We ran into a problem where for historical reasons, there were some existing inbound rules in the Target DB that prevented us from using the Target DB as the destination security group, so we used a CIDR range that covered the Target DB range of addresses. This should be an unusual situation and you can probably ignore it.
![Outbound Rules wiht security group destination](/_images/connect-quicksight-security-group-outbound-rules-cidr.png)

## DNS Resolver Endpoints (optional)

You only need to fill this in for cases where the DNS lookup of your Target DB `Endpoint` would be incorrect against Public DNS. The usual use case for this is when you have a somewhat complicated VPC Peering setup where your Target DB is on the other side of a VPC Peering setup. In that case, only the DNS Resolver in your private VPC may know the proper resolution of the Target DB Endpoint.

In our case, we had the unusal situation that our Target DB had a public IP address, so when Quicksight would do a DNS Query on the Target DB `Endpoint` name, it would get the Public IP address which was not valid for the `VPC Connection`. The workaround is for Quicksight to use the local VPC DNS Resolver. And thus our need to setup the `DNS Resovler Endpoints`

It took a while to figure out this was why we could never get the `VPC Connection` to work until we set this up. The diagnostics of the `VPC Connection` Validation check does not differentiate between Networking, DNS, or username/password problems. An issue in anyone of those can make the connection validation fail.

### Route53 Resolver Inbound Endpoints

#### Create a Security Group for the Resolver

The resolver needs to have a security group for itself to allow the DNS requests to get to it.

##### Inbound Rules

- Create a new Security Group and call it something like `quicksight-route53-resolver` or whatever fits your nameing scheme.
- Set the `Inbound Rules` to allow for DNS UDP and DNS TCP from all sources on the VPC CIDR Block

![Resolver Security Group Inbound Rules](/_images/connect-quicksight-security-group-dns-resolver-inbound.png)

##### Outbound Rules

Can leave the default outbound to all rule

#### Setup the Route53 Endpoint Resolver

You will need to go to the Route53 Console and select `Resolver->Inbound endpoints` and click on the `Create Inbound Endpoint` button.

- Set the `Endpoint name`
  - Something that fits your naming scheme
  - Our example is `quicksight-prod`
- Set the VPC ID to be the same as your `VPC-ID` used for your Target DB
- Set the Security Group to the Security Group you created
- Set the Availability Zone / Subnet for two IP Addresses for the resolver
  - Could be any that are routable to the Subnet that is assigned to the `VPC Connection`.
  - Should be a private subnet
  - Might as well make one of them the same Subnet used by the `VPC Connection`
  - Check the option `Use an IP address that is selected automatically` for both
  - Click `Submit` when done

![Route53 Create Resolver Inbound Endpoint](/_images/connect-quicksight-route53-create-inbound-endpoint.png)

You will then end up with an `Inbound Endpoint` that will have been assigned two IP addresses. These addresses will be needed to supply to the `VPC Connection` and be used to update the Quicksight Security Group.

![Route53 Quicksight Inbound Resolver](/_images/connect-quicksight-route53-quicksight-inbound-resolver.png)

In this example the two IP Addresses are

- 10.0.100.120
- 10.0.101.80

#### Update the Quicksight Security Group for DNS

If you are using the DNS Resolver Inbound Endpoints feature, you will also have to update the `Outbound Rules` of the Security Group we created earlier for the `Quicksight Network Interface`. This is to enable Quicksight to be able to access the DNS Resolver as well as the Target DB.

To do this we will add DNS UDP and DNS TCP to the `Output Rules` of the `Amazon-QuickSight-access` Security Group for each of the two IP Addresses from the `Inbound Resolver` we just created. Note that you need to have the CIDR suffix `/32` at the end when entering them into the Security Group editor.

![Quicksight Security Group with DNS Resolver IPs](/_images/connect-quicksight-security-group-quicksight-with-dns-resolver-ips.png)

## Create the Actual VPC Connection

Now we have everything we need to setup the actual `VPC Connection` in the Quicksight management console.

You will of course need to have proper permissions to access and manage Quicksight in your account. That is beyond the scope of this article. We're going to assume you have all that already.

- Enter the Quicksight Console, click on your username on the topr right of the page and select `Manage Quicksight`

![Home page select Manage Quicksigth](/_images/connect-quicksight-quicksight-select-manage.png)

- Then select `Manage VPC Connections` in the left hand Navbar

![Select Manage VPC Connection from Navbar](/_images/connect-quicksight-qucicksight-select-manage-vpc-connections.png)

- Click on `Add VPC Connection` to create the new connection

![Add VPC Connection](/_images/connect-quicksight-quicksight-add-vpc-connection.png)

Fill in the form with the info we found or created earlier:

- `VPC Connection Name`
  - Appropriate name of the connection based on your naming conventions
  - Our example: `my-aurora-db`
- `VPC ID`: The `VPC ID` we have been using earlier
  - Our example ends with `2aed`
- `Subnet ID`: The Subnet we chose for the Quicksight `Network Interface`
  - In our example it ends with `90dc`
- `Security Group ID`: The Security Group we created for Quicksight
  - Our example: `Amazon-QuickSight-access` (ended in `16e8`)
- `DNS Resolver Endpoints`: The IP addresses from the DNS Resolver `Inbound Endpoints`
  - Our example: `10.0.100.120` and `10.0.101.80`

![VPC Connection Form](/_images/connect-quicksight-vpc-connection-form.png)

## Create a Dataset using the VPC Connection

Now that the `VPC Connection` has been setup, we can use it to create a Dataset from the Target DB.

- Click on the `Quicksight` logo on the top left of the screen to get back to the Quicksight home page.
- Click on `Datasets` at the bottom of the left Navbar
- Click on `New dataset` on the top right of the page.

![Getting to the Dataset create page](/_images/connect-quicksight-getting-to-new-dataset.png)

- Click on `Aurora` (or other source, but we're not going to show other sources in this article)

### Fill in the `New Aurora data source` form

- `Data source name`: Our example is `my-data-source`
- `Connection type`: Select the VPC connection we created
  - `my-aurora-db`
    ![Select VPC Connection](/_images/connect-quicksight-select-vpc-connection.png)
- `Database connector`: `PostgreSQL`
- `Database server`: The `Endpoint` of your Aurora DB
  - This is the fully qualified DNS name of your DB endpoint
  - You can find it in the `Connectivity & security` tab on the DB's RDS Console page
  - You probably want to use a reader endpoint

* `Port`: The proper port for your Target DB
  - Postgres default is `5432`
* `Database Name`: The name of the database within the RDS of interest
  - Same name you would use in a DB connection or in psql to connect to your working DB's
* `Username`: The db username needed to connect
* `Password`: The db password

### Click on `Validate Connection`

It should turn to `Validated` with a checkmark if all went well. Should happen within a few seconds.

At this point you can now click on the `Create data source` button and do the normal Quicksight data source stuff. That is all independent of the VPC Connection and is not part of this article.

## If the VPC Connection fails to Validate

If the Validate failed you are going to have to check several things. There will be an error message. You can click on the `details` link, but its probably not going to be helpful.

The error diagnosicts for the VPC Connection rarely gives you any more info other than it could not connect to the DB.

You need to determine if its because of:

- The routing from the Quicksight Network Interface to the Target DB
- The Security Group settings
- Basic error in the regular connection parameters (`Database name`, `Username`, `Password`)
- The `Database Server` is the correct value and Quicksight DNS query is getting the right value (private IPs not public or nothing at all)

### Check for basic connectivity

You can check the basic connectivity (routing and security groups) is working using the `Reachability Analyzer` in the VPC Console. Unfortunately the analyzer has a limited set of elements that can be specified as a Source and Destination. The only one that applies to the Quicksight VPC Connection as a source and Aurora RDS as a Destination are `Network Interfaces`. So we're going to need to find the IDs of those two Network Interfaces.

#### Find the ID of the VPC Connection Network Interface

You will need to know the `Network Interface` ID of the interface created for the VPC Connection. To figure that out go to the EC2 Console page and click on `Network Interfaces` under `Network & Security` in the Navbar on the left

Then search for the name you used for the Quicksight connection. Our example was `my-aurora-db` It will be part of the description of the `Network Interface` associated with that connection. In our example it starts with `eni-0b9e`

![Search for Network Interface](/_images/connect-quicksight-search-for-network-interface.png)

#### Find the ID of the Target DB Network Interface

You will need to know any of the `Network Interface` IDs of the Target DB. There can be a few as there may be one per Availability Zone. It doesn't matter which one you choose.

- Still on the EC2 Console page `Network Interfaces` page, search for the Target DB's Security Group name.
  - You can find the Target DB Security Group name on the RDS Console page for your Target DB under the `Connectivty & Security` tab labeled `VPC security groups`
- Select any one of them.
  - Our example starts with: `eni-050d`

### Run the Reachability Analyzer

Go to the VPC Console and click on the `Create and analyze path` button on the top right of the page

![Rechability Analyzer](/_images/connect-quicksight-reachability-analyzer.png)

- Give it a name
- Select `Network Interfaces` for the `Source type` and `Destination type`
- Specify the `Network Interface ID` of the Quicksight `Network Interface` we found
  - Starts with `eni-0b9e` in our example
- Specify the `Network Interface ID` of the Target DB `Network Interface` we found
  - Starts with `eni-050d` in our example
- Specify `5432` for the `Destination port`
  - Or whatever port you set for your Target DB if not Postgres
- Protcol is `TCP`

![Start Create and Analyze](/_images/connect-quicksight-create-and-analyze-path.png)

- Click on `Create and analyze path`

If it all works you should see:

![Analyze Success](/_images/connect-quicksight-analyze-success.png)

If that works, you configured the DNS Endpoint Resolver, but your VPC Connection / Dataset creation still doesn't work, you may want to repeat the `Reachability Analyzer` test for the DNS TCP and UDP ports in addition to the Postgres Port to double check for the DNS passing properly between the resolver and Quicksight.

## Conclusion

If the `Reachability Analyzer` said connectivity is ok and it still doesn't work, then its probable that one of the other basic connection parameters is wrong, or there is something wrong with the `Endpoint` name. If you hadn't tried setting up the DNS Endpoint Resolver option, you can try that to see if there was a problem with how Quicksight was resolving the DNS for your `Endpoint`. That was what started this whole journey for me.

Otherwise, hopefully this did work for you and you can now happly view your Target DB in Quicksight!
