+++
date = "2017-03-01T10:54:24+02:00"
title = "Using Namecheap, Amazon S3, Amazon Route 53, and Hugo"
subtitle = "How I made this blog"
draft = false
tags = ["aws", "s3", "route53", "hugo"]
+++
Time for the obligatory "How I made the website you're reading right now I'M SO META" post.
Turns out this was not a trivial process, particularly all of the DNS stuff that I barely understood
(and frankly still barely understand). My goal was to make this blog as quickly and
cheaply as possible, and I think I found a pretty good solution... Maybe. Feel free
to correct me in the comments.

## Step one: Buy a domain name

First we need a domain name. This will provide the mapping to our web server whenever
we get around to making that. There are tons of domain name providers, I decided to
go with [Namecheap](https://www.namecheap.com/) because I liked the name, also my chosen
domain was available for pretty cheap.

## Step two: Setup S3 buckets

Next we need an actual web server. Since I'm making a static webpage, I decided to
just use [Amazon S3](https://aws.amazon.com/s3/) because it is reliable and not super
expensive. We need to add two buckets, one with the _www_ version of your domain
and the other with just your host name. I used [this great tutorial](http://docs.aws.amazon.com/AmazonS3/latest/dev/website-hosting-custom-domain-walkthrough.html)
to get everything setup properly. **DON'T SETUP THE ROUTE 53 DNS YET! READ ON TO DECIDE IF YOU NEED TO!**

## Step three: Setup your DNS

There are two options for this:   

1. Use the free Namecheap DNS and point to your S3 buckets  
2. Use [Amazon Route 53](https://aws.amazon.com/route53/) ($0.50 per host, $0.50 per million connections)  

#### Which DNS should I use?

This depends on a couple of factors. I tried both, and I decided to use Amazon Route 53
*only* because I setup a private email with Namecheap (see [Step four](#step-four) below for how to do that)
and since I was using S3 as my web server, for some reason Namecheap thought I was using a
custom DNS (even though I wasn't) and none of my emails were being received. If you decide to
not setup a custom email, then using the free Namecheap DNS works just fine. There are some other
factors as well, like the fact that the Namecheap DNS is free, and it doesn't propagate changes
as quickly as I would like. For a static website where you are probably only setting this stuff up
once though, quick changes probably aren't super critical.

#### Namecheap DNS

If you decide to go with the Namecheap DNS, then all you need to do is go to the "Advanced DNS"
tab when managing your Domain in the Namecheap interface. You will be adding two CNAME entries.  

1. Host: @ Value: **your-domain**.s3-website-us-west-1.amazonaws.com.
2. Host: www Value: www.**your-domain**.s3-website-us-west-1.amazonaws.com.

**NOTE:** Your region (the us-west-1) may be different, so double check what the value will be.
You might be able to use the Amazon S3 URL without a region, but I didn't try that.

That's it!

#### Amazon Route 53 DNS

If you decide to go with Amazon Route 53 for your DNS, then just do Step 3 from
[this tutorial](http://docs.aws.amazon.com/AmazonS3/latest/dev/website-hosting-custom-domain-walkthrough.html).
In order to set Route 53 as your DNS provider, we have to go to Namecheap and
use a custom DNS. Use [this tutorial](https://www.namecheap.com/support/knowledgebase/article.aspx/767/10/how-can-i-change-the-nameservers-for-my-domain)
to set that up. You need to choose the "Custom DNS" option, and add all of the name servers that Route 53
gave you.

That's it!

## Step four: Setup a custom email. Optional, but awesome {#step-four}

Now it's time to make a custom email on your domain so you look all professional and stuff.
Again I decided to use [Namecheap](https://www.namecheap.com/hosting/email.aspx) for this service.
You can probably use any other service you want, we just need to configure Route 53
(like I said I couldn't get Namecheap to route my emails when using S3) to point to our new private email.
Thankfully, this is super easy. All you need to do if you are using the Namecheap private email
is add one MX record with this value:
```
10 mx1.privateemail.com.
20 mx2.privateemail.com.
```
You can also add a CNAME entry for mail.**your-domain** and point that to privateemail.com.
According to everything I read this isn't necessary, but I did it anyway.

## Step five: Make the actual friggin' website

Now we finally have all our setup out of the way, we get to build our actual website.
Yay. For this I decided to use [Hugo](https://gohugo.io/). It seemed like it was a quick
and easy solution for static webpages, and it turns out it is pretty easy to use. I followed
the [quickstart guide](https://gohugo.io/overview/quickstart/), picked a [cool theme](http://themes.gohugo.io/beautifulhugo/)
and built my website. After that, upload your site to S3 and enjoy!
