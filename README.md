# Fover

<!-- ## Contributing

Before submitting a PR, make sure to generate the required files:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
``` -->

## In development
This project is still under development. Please check back later!

## Quick start with Copyparty
**Requires Docker**<br>
It won't take more than 10 minutes.
> Note: The following instructions are for setting up Copyparty, a self-hosted file server, to serve your medias.

1. Create the "Fover" directory and a subdirectory "FoverServer"
```bash
mkdir -p Fover/FoverServer
```

### Without HEIC support (fast setup)

2. Create a docker-compose.yml file in the "Fover" directory with the following content:
```yaml
services:
  copyparty:
    image: copyparty/ac:latest
    container_name: copyparty
    restart: unless-stopped
    ports:
      - "3923:3923"
    volumes:
      - /path/to/Fover/FoverServer:/mnt/photos
      - /opt/copyparty/config:/cfg
    command: >
      -v /mnt/photos:photos:rwdgr,you
      -a you:yourPassword
      -e2dsa
      --no-robots
    # Change "you" to your username and "yourPassword" to a secure password
```

### With HEIC support
2. Create a docker-compose.yml file in the "Fover" directory with the following content:

```yaml
services:
  copyparty:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: copyparty
    restart: unless-stopped
    ports:
      - "3923:3923"
    volumes:
      - /home/freebox/Fover/FoverServer:/mnt/photos
      - /opt/copyparty/config:/cfg
    command:
      - "-v"
      - "/mnt/photos:photos:rwdgr,you"
      - "--th-size"
      - "300x300"
      - "--th-ff-jpg"
      - "--th-poke"
      - "1"
      - "--th-dec"
      - "vips,ff"
      - "-a"
      - "you:yourPassword"
      - "-e2dsa"
      - "-e2ts"
      - "--no-robots"
    # Change "you" to your username and "yourPassword" to a secure password

```

Create a Dockerfile in the same directory with the following content:

```Dockerfile
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    ffmpeg \
    libvips \
    libheif1 && \
    rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED && \
    pip3 install --no-cache-dir copyparty pyvips && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["copyparty"]
```


3. Start the Copyparty server with the following command in the "Fover" directory:
```bash
docker compose up -d
```
___ 
Now we have to make it accessible from the Internet. 

For that, you have two options:

### Option 1 :  Port forwarding
Configure your router to forward incoming traffic on a specific port (e.g., 3923) to the local IP address of the machine running Copyparty. This allows you to access your server using your public IP address and the forwarded port.

1. Find your local IP address
```bash 
ip route get 1.1.1.1 | grep -oP 'src \K\S+'
```
2. Open the port on your router

Access your router's admin interface *usually http://192.168.0.1 or http://192.168.1.1* and create a port forwarding rule:

| Field | Value |
|---|---|
| Destination IP | Your server's local IP (see above) |
| External port | `3923` |
| Internal port | `3923` |
| Protocol | `TCP` |

You can now log in to the app by entering http://your-public-ip:3923 in the IP Address field.

### Option 2 : Cloudflare tunnel
If your ISP blocks port forwarding, Cloudflare Tunnel is an alternative that requires no open ports.

> ⚠️ **Privacy notice**: Unlike port forwarding, your photos will transit through **Cloudflare's servers**. Cloudflare states they do not analyze your content, but they technically have access to your data. Use this option only if port forwarding is not possible.

#### Quick tunnel (no domain required)
Download [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) and run:

```bash
cloudflared tunnel --url http://127.0.0.1:3923
```

A temporary URL will be displayed in the terminal (e.g. `https://random-words.trycloudflare.com`).
Copy it into Fover as your server address.

> ⚠️ This URL changes every time you restart the tunnel. You will need to update it in Fover each time.

---

#### Permanent tunnel (requires a domain managed by Cloudflare)

A permanent tunnel gives you a fixed URL (e.g. `https://photos.mydomain.com`) that never changes.

**1. Create the tunnel**

Go to [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → **Networks → Tunnels → Create a tunnel**.  
Select **Cloudflared**, give it a name (e.g. `fover-tunnel`), and save. Copy the token displayed.

**2. Add `cloudflared` to your `docker-compose.yml` and update the Copyparty command**

```yaml
services:
  # Your existing copyparty service

  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      - TUNNEL_TOKEN=your_token_here
```

> Replace `your_token_here` with the token displayed in the Cloudflare dashboard.

**3. Configure the public hostname**

In the Cloudflare dashboard, under **Public Hostname**:

| Field | Value |
|---|---|
| Subdomain | `photos` |
| Domain | `mydomain.com` |
| Service Type | `HTTP` |
| URL | `copyparty:3923` |

> Use `copyparty` (the Docker service name) instead of `localhost`.

**4. Start**

```bash
docker compose up -d
```

Your server is now accessible at `https://photos.mydomain.com`. HTTPS is handled automatically by Cloudflare — no certificate needed.
