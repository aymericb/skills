This repository is a collection of the skills I use, or may have used at some point. 

I make no promise that this will work out for you; use at your own risks.

## Organization

```
skills/
├── aymeric/      # My own skills
├── mattpocock/   # Matt Pocock skills from https://github.com/mattpocock/skills.git
```

## Maintenance

The skills from thirdparties are added as git subtrees, which making pulling from this repository simple. 

First you need to set up the additional upstream repositories

```sh
git remote add mattpocock https://github.com/mattpocock/skills.git
git fetch mattpocock
```

Then you can pull the latest version in repository

```sh
git subtree pull \
  --prefix=skills/mattpocock \
  mattpocock \
  main 
```

On first install use `git subtree add` instead of `pull`. 
 
In case of "working tree has modifications" use the `git update-index --refresh` to resolve.
