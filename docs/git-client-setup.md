# Git Client Setup

How to connect your local git to the Forgejo server — works the same whether the server is running locally or deployed to production.

## Prerequisites

- [Git](https://git-scm.com/) installed
- [Tea CLI](https://gitea.com/gitea/tea/releases) installed and in your PATH

## 1. Configure Tea

### Add your Forgejo server

Local:

```bash
tea login add --name local --url http://localhost:3000 --token YOUR_TOKEN
```

Production:

```bash
tea login add --name prod --url https://git.yourdomain.com --token YOUR_TOKEN
```

### Set a default server

```bash
tea login default local
```

All `tea` commands will use this server unless you specify otherwise with `--login`.

### List configured servers

```bash
tea login ls
```

## 2. Generate an API Token

1. Log in to your Forgejo instance in the browser (`http://localhost:3000` or `https://git.yourdomain.com`)
2. Go to **Settings > Applications**
3. Under **Generate New Token**, give it a name and select the scopes you need (at minimum: `repository`, `user`, `organization`)
4. Click **Generate Token** and copy it — you won't see it again

If you have Docker access to the server, you can also generate a token from the CLI:

```bash
docker exec --user git forgejo forgejo admin user generate-access-token \
  --username YOUR_USER \
  --token-name "cli" \
  --scopes "write:repository,write:user,write:organization"
```

## 3. Create a Repository

```bash
tea repo create --name my-project --private
```

## 4. Push an Existing Project

```bash
cd /path/to/your/project
git init
git remote add origin http://YOUR_SERVER/YOUR_USER/my-project.git
git push -u origin main
```

Replace `YOUR_SERVER` with `localhost:3000` (local) or `git.yourdomain.com` (production).

## 5. Git Authentication

### Option A: Credential store (HTTPS)

```bash
git config --global credential.helper store
```

On first push, enter your username and **token** as the password. Git remembers it after that.

### Option B: SSH

1. Copy your public key:

   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

2. Add it in Forgejo: **Settings > SSH / GPG Keys > Add Key**

3. Use the SSH remote URL:

   Local:

   ```bash
   git remote add origin ssh://git@localhost:2223/YOUR_USER/my-project.git
   ```

   Production:

   ```bash
   git remote add origin git@git.yourdomain.com:YOUR_USER/my-project.git
   ```

## 6. Clone a Repository

```bash
git clone http://YOUR_SERVER/YOUR_USER/my-project.git
```

## 7. Useful Tea Commands

```bash
tea repo ls                    # list your repos
tea repo delete user/repo      # delete a repo
tea issue ls                   # list issues
tea issue create               # create an issue
tea pr ls                      # list pull requests
tea pr create                  # create a PR
```

## 8. Switching Between Local and Production

If you have both servers configured:

```bash
tea login default local        # switch to local
tea login default prod         # switch to production
```

Or use `--login` per command:

```bash
tea repo create --name my-project --private --login prod
```

To migrate a repo's remote from local to production:

```bash
git remote set-url origin https://git.yourdomain.com/YOUR_USER/my-project.git
```
