# Git Client Setup

How to connect to the Forgejo server from any machine.

## Prerequisites

- [Git](https://git-scm.com/)
- [Tea CLI](https://gitea.com/gitea/tea/releases) (optional, for repo management)

## 1. SSH Key Setup

### Generate a key (skip if you already have one)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_forgejo -C "your-email@example.com"
```

### Add the key to Forgejo

1. Copy the public key:

   ```bash
   cat ~/.ssh/id_forgejo.pub
   ```

2. Log in to your Forgejo instance in the browser
3. Go to **Settings > SSH / GPG Keys > Add Key**
4. Paste the public key and save

### Configure SSH

Add this to `~/.ssh/config` (create the file if it doesn't exist):

```
Host git.yourdomain.com
  Port 2222
  User git
  IdentityFile ~/.ssh/id_forgejo
```

Replace `git.yourdomain.com` with your Forgejo domain and `2222` with your SSH port.

Test the connection:

```bash
ssh -T git@git.yourdomain.com
```

## 2. Generate an API Token

1. Log in to Forgejo in the browser
2. Go to **Settings > Applications**
3. Under **Generate New Token**, give it a name and select scopes (`repository`, `user`, `organization`)
4. Click **Generate Token** and copy it — you won't see it again

## 3. Configure Tea CLI

```bash
tea login add --name myserver --url https://git.yourdomain.com --token YOUR_TOKEN
tea login default myserver
```

If the server doesn't have a valid TLS certificate yet:

```bash
tea login add --name myserver --url https://git.yourdomain.com --token YOUR_TOKEN --insecure
```

Verify:

```bash
tea login ls
```

## 4. Create a Repository

```bash
tea repo create --name my-project --private
```

## 5. Push an Existing Project

```bash
cd /path/to/your/project
git init
git add -A
git commit -m "initial commit"
git remote add origin git@git.yourdomain.com:YOUR_USER/my-project.git
git push -u origin main
```

## 6. Clone a Repository

```bash
git clone git@git.yourdomain.com:YOUR_USER/my-project.git
```

## 7. HTTPS Alternative (instead of SSH)

If you prefer HTTPS over SSH:

```bash
git config --global credential.helper store
git remote add origin https://git.yourdomain.com/YOUR_USER/my-project.git
git push -u origin main
```

Enter your username and **API token** as the password on first push. Git remembers it after that.

## 8. Multiple Servers

```bash
tea login add --name local --url http://localhost:3000 --token LOCAL_TOKEN
tea login add --name prod --url https://git.yourdomain.com --token PROD_TOKEN

# Switch default
tea login default prod

# Or per command
tea repo create --name my-project --private --login local
```

To change a repo's remote:

```bash
git remote set-url origin git@git.yourdomain.com:YOUR_USER/my-project.git
```

## 9. Useful Tea Commands

```bash
tea repo ls                    # list repos
tea repo create --name NAME    # create repo
tea repo delete user/repo      # delete repo
tea issue ls                   # list issues
tea issue create               # create issue
tea pr ls                      # list pull requests
tea pr create                  # create pull request
```
