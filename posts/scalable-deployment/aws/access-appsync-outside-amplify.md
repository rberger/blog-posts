---

title: Accessing AppSync APIs that require Cognito Login outside of Amplify
menu_order: 1
post_status: publish
post_excerpt: Access your AppSync GraphQL APIs that require Cognito Logins with arbitrary tools outside of Amplify Apps

---

## The Need

You have this great Amplify App using AppSync GraphQL. You eventually find that you need to be able to access that data in your AppSync GraphQL database from tools other than your Amplify App. Its easy if you just have your AppSync API protected just by an API Key. But that isn't great security for your data!

One way to protect your AppSync data is to use [Cognito Identity Pools](https://docs.amplify.aws/lib/graphqlapi/authz/q/platform/js/#cognito-user-pools). Amplify makes it pretty transparent if you are  using Amplify to build your clients. AppSync lets you do really nice [table and record level access control based on logins and roles](https://docs.aws.amazon.com/appsync/latest/devguide/security-authorization-use-cases.html).

What happens if you want to access that data from something other than an Amplify based client? How do you "login" and get the JWT credentials you need to access your AppSync APIs?

## Use AWS CLI

The most general way is to use the AWS CLI to effectively login and retrieve the JWT credentials that can then be passed in the headers of any requests you make to your AppSync APIs.

Unfortunately its not as easy as just having your login and password. It also depends on how you configured your Cognito Identity Pool and its related Client Apps.

### Cognito User Pool Client App

You can have multiple Client Apps specified for your Cognito User Pool. I suggest  having one dedicated to these external applications. That way you can have custom configuration just for this and not disrupt your main  Amplify apps. Also you can easily turn it off if you need too.

![User Pool Client Apps](/_images/User-pool-app-clients.png "User Pool Client Apps")

In my case I created a new client app `shoppabdbe800b-rob-test2` as a way to test a client app with no `App Client Secret`. This makes it easier to access from the command line as you do not have to generate a Secret Hash (will describe how to deal with that below).

![App Client Config with no secret](/_images/app-client-config-no-secret.png "App Client Config with no secret")

If you want to allow admin level access (ie a user with admin permission) you need to check `Enable username password auth for admin APIs for authentication (ALLOW_ADMIN_USER_PASSWORD_AUTH)`

If you want to allow regular users to login you must also select `Enable username password based authentication (ALLOW_USER_PASSWORD_AUTH)`

The defaults for the other fields should be ok. Be sure to save your changes.

### Minimal IAM permissions

As far as I can tell, these are the minimal IAM permissions to make the aws `cognito-idp` command work for admin and regular users of AppSync (replace the Resource arn with the arn of the user pool[s] you want to control):

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "cognito-idp:AdminInitiateAuth",
                "cognito-idp:AdminGetUser"
            ],
            "Resource": "arn:aws:cognito-idp:us-east-1:XXXXXXXXXXXXX:userpool/us-east-1_XXXXXXXXX"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "cognito-idp:GetUser",
                "cognito-idp:InitiateAuth"
            ],
            "Resource": "*"
        }
    ]
}
```

### Get the Credentials with no App Client Secret

This example is if you did not set the App Client Secret.

You should now be able to get the JWT credentials from the AWS CLI.

This assumes you have[ set up your](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) `~/.aws/credentials` file or whatever is appropriate for your command line environment so that you have the permissions to access this service.

* When using the `ADMIN_USER_PASSWORD_AUTH`

```
aws cognito-idp admin-initiate-auth --user-pool-id us-east-1_XXXXXXXXXX --auth-flow ADMIN_USER_PASSWORD_AUTH --client-id XXXXXXXXXXXXX --auth-parameters USERNAME=username1,PASSWORD=XXXXXXXXXXXXX > creds.json
```

* When using the `USER_PASSWORD_AUTH`

```
aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH --client-id XXXXXXXXXXXXX --auth-parameters USERNAME=username2,PASSWORD=XXXXXXXXXXXX > creds.json
```

Of course replace the `XXXX`'s with the actual values.

* `user-pool-id` - The pool id found at the top of the _User Pool Client Apps_ page
* `client-id` - The `client-id` of the `app client` you are using
* `USERNAME` - The Username normally used to login to your Amplify app
* `PASSWORD` - The Password normally used to login to your Amplify app

The results will be in `creds.json`. (You could not use the `> creds.json` if you want to just see the results)

### Get the Credentials when there is an App Client Secret

This assumes you have an App Client that has an `app secret key` set.

The main thing here is you need to generate a `secret hash` to send along with the command.

You can do that by creating a little python program to generate it for you when you need it:

```python3
#!/usr/bin/env python3

import sys
import hmac, hashlib, base64

if (len(sys.argv) == 4):
    username = sys.argv[1]
    app_client_id = sys.argv[2]
    key = sys.argv[3]
    message = bytes(sys.argv[1]+sys.argv[2],'utf-8')
    key = bytes(sys.argv[3],'utf-8')
    secret_hash = base64.b64encode(hmac.new(key, message, digestmod=hashlib.sha256).digest()).decode()

    print("SECRET HASH:",secret_hash)
else:
    (print("len sys.argv: ", len(sys.argv)))
    print("usage: ",  sys.argv[0], " <username> <app_client_id> <app_client_secret>")
```
Save the file someplace that you can execute it from like `~/bin/app-client-secret-hash` and make it executable (`chmod a+x ~/bin/app-client-secret-hash`).

You will need:

* `app-client-id` - The `client-id` of the `app client` you are using
* `app-client-secret` - The secret of the `app client` you are using (its on the App Client page of the User Pool)
* `USERNAME` - The Username normally used to login to your Amplify app

To use:

```
~/bin/app-client-secret-hash  <username> <app_client_id> <app_client_secret>
```
Where of  course you replace the arguments with the actual values. 

The result is a `secret-hash` you will use in the following command to get the actual JWT credentials


```
aws cognito-idp admin-initiate-auth --user-pool-id us-east-1_XXXXXXXXXX --auth-flow ADMIN_USER_PASSWORD_AUTH --client-id XXXXXXXXXXXXX --auth-parameters USERNAME=username3,PASSWORD='secret password',SECRET_HASH='secret-hash' > creds.json
```

You could do the same thing with `USER_PASSWORD_AUTH` if you nee that instead

```
aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH --client-id XXXXXXXXXXXXX --auth-parameters USERNAME=rob+admin,PASSWORD=XXXXXXXXX,SECRET_HASH='secret-hash' > creds.json
```

## Using the Credentials

How you use these credentials depends on what tool or  how you are trying to access your AppSync APIs.

### From some Javascript

You can just add in the `IdToken` from the `creds.json` as an `Authorization` header when you build the request:

```javascript
function graphQLFetcher(graphQLParams) {
  const APPSYNC_API_URL = "TYPE_YOUR_APPSYNC_URL";
  const credentialsAppSync = {
    Authorization: "eyJraWQiOiI1dVUwMld...",
  };
  return fetch(APPSYNC_API_URL, {
    method: "post",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...credentialsAppSync,
    },
    body: JSON.stringify(graphQLParams),
    credentials: "omit",
  }).then(function (response) {
    return response.json().catch(function () {
      return response.text();
    });
  });
}
```

If you are using some GraphQL tool that needs to access your AppSync APIs. The tool should have a way that you can supply the token and it will add it as an `Authorization` header for its own requests.

Do let me know if you have some examples of tools that would make use of this.

## References

* [Explore AWS AppSync APIs with GraphiQL from your local machine](https://aws.amazon.com/blogs/mobile/appsync-graphiql-local/ "Explore AWS AppSync APIs with GraphiQL from your local machine")
* [How do I troubleshoot "Unable to verify secret hash for client <client-id>" errors from my Amazon Cognito user pools API?](https://aws.amazon.com/premiumsupport/knowledge-center/cognito-unable-to-verify-secret-hash/ "How do I troubleshoot "Unable to verify secret hash for client <client-id>" errors from my Amazon Cognito user pools API?")

