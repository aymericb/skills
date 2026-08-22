This repository is a collection of the skills I use, or may have used at some point. 

I make no promise that this will work out for you; use at your own risks.

## Organization

```
skills/
├── aymeric/      # My own skills
├── mattpocock/   # Matt Pocock skills from https://github.com/mattpocock/skills.git
```

## Install

```sh
npx skills@latest add aymericb/skills 
```

## Maintenance

Third-party skills are added as git subtrees. Matt Pocock's repo has its skills under an upstream `skills/` folder, so we split that path first and mount only those contents at `skills/mattpocock/`.

Set up the upstream remote once:

```sh
git remote add mattpocock https://github.com/mattpocock/skills.git
git fetch mattpocock
```

Split the upstream `skills/` folder, then add or pull it:

```sh
git fetch mattpocock
git subtree split --prefix=skills -b mattpocock-skills-only mattpocock/main

# First install:
git subtree add --prefix=skills/mattpocock mattpocock-skills-only

# Later updates:
git subtree pull --prefix=skills/mattpocock . mattpocock-skills-only

git branch -D mattpocock-skills-only
```

If git complains that the working tree has modifications, run `git update-index --refresh` and retry.
