---

title: Blogging Once More
menu_order: 1
post_status: publish
post_excerpt: Time to start blogging, so of course, have to spend days tweaking up the blog and the blog process before writing anything!

---

## Its Time to Blog Again!

I've been itching to do some blogging about various projects I've been working on for both [work](https://www.visx.live) and personal. In particular since I had the honor of being invited to be part of the [AWS Community Builders](https://aws.amazon.com/developer/community/community-builders/) I need to up my blogging game.

## Joining the POSSE

One goal is to do it in the [_Publish (on your) Own Site, Syndicate Elsewhere_ POSSE](https://indieweb.org/POSSE) style. I.E. publish on my personal blog but then have it (hopefully) automatically syndicated to other sites like [Medium](https://medium.com/me/stories/drafts), [Dev.to](https://dev.to/rberger), [Hashnode](https://hashnode.com/@rberger), etc. I.e. Write Once, Publish Everywhere.

## Markdown, Emacs and Github at the Source

And I want to write it in Markdown with Emacs and have the authoritative source in Github. What more is there to say?

## Wordpress as the Personal Website

My personal website is based on Wordpress running on AWS lightsail. I have a love / hate relationship with Wordpress. Its one of those technologies that are powerful because so many people use it. And I have to help other folks with their Wordpress setups, so I want to keep my finger in it. I've tried the various static sites and its been at least so far, worth keeping it there.

Unfortunately, Wordpress is also the most painful to work with Markdown and have content come from Github.

### Git it Write makes it possible

I have found what looks like a good solution: [Git it Write](https://wordpress.org/plugins/git-it-write/)

It is a Wordpress plugin that allows you to connect a github repo to your Wordpress instance. It uses a webhook so that everytime you update a specified branch of a github repo, it will push the markdown and images from the repo into the Wordpress as a Post, Page Ad, Reusable Block, or Attachment. It uses YAML frontmatter in the markdown source to control some of the meta info for the post.

You organize the file hierarchy in the repo to match the Permalink hierarcy of your website. In my case, my default permalink is a custom `/%category%/%postname%/` ![Permalink Settings](/_images/permalink-settings.png "Permalink Settings"). And the file layout is like this:

```
.
├── LICENSE
├── README.md
├── _images
│   ├── permalink-settings.png
│   └── san-juan-mountains.jpg
└── posts
    ├── anti-ageing
    ├── blogging
    │   └── first-git-blog-post.md
    ├── how-the-world-works
    │   ├── creating_the_future_of_abundance
    │   └── demand_transformation
    ├── howto
    ├── macintosh
    ├── robotics-2
    ├── scalable-deployment
    ├── sysadmin
    ├── telecom
    └── uncategorized
```

Right now I only have the one article that you are reading now `first-get-blog-post.md` but I put in all the other categories I already had in my blog from before as directories as placeholders.

Also notice the `_images` directory. Unfortunately, you have to put all the images you use in any post in this one top level `_images` directory. So you have to make the filenames unique across posts and its a shame in terms of keeping things organized. But the good news is the plugin takes care of geting the images into Wordpress.

You refer to the image in our Markdown like:

```
![Permalink Settings](/_images/permalink-settings.png "Permalink Settings")
```

The setup of the plugin is pretty easy:

![Git it write top level settings](/_images/git-it-write-settings.png "Git it Write top level settings")

Just click on the `+ Add a new repository to publish posts from` and fill in the info about your repo:

![Repo settings](git-t-write-repo-settings.png "Git it Write Repo Settings")

You can set a subdirectory in the repo if you want to carve up things like Posts, Pages, etc in the same repo.

__NOTE:__ the `_image_` directory is still at the top of the repo and shared across them all.

The documenation for _Git it Write_ is at https://www.aakashweb.com/docs/git-it-write/

In any case, it seems like a pretty nice solution for now to allow me to write in markdown and make Git the authoritative source for posts. Which means I can use the git repo to push to other sites like Medium and Dev.to. My experiences attempting that will hopefully be in a future post.
