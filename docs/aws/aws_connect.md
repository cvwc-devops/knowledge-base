# AWS 

## Common AWS Services
| Service | Bookmark URL |
| ------- | ------------ |
| EC2 | https://console.aws.amazon.com/ec2/ |
| S3 | https://console.aws.amazon.com/s3/ |
| IAM | https://console.aws.amazon.com/iam/ |
| VPC | https://console.aws.amazon.com/vpc/ |
| CloudWatch | https://console.aws.amazon.com/cloudwatch/ |
| RDS | https://console.aws.amazon.com/rds/ |
| Lambda | https://console.aws.amazon.com/lambda/ |
| ECS | https://console.aws.amazon.com/ecs/ |
| EKS | https://console.aws.amazon.com/eks/ |
| SSO | https://mycompany.awsapps.com/start |

The AWS Management Console URL is:
```
https://console.aws.amazon.com/
```
> Notes:
> You’ll be prompted to sign in with:
> - Root user email or
> - IAM user / IAM Identity Center (SSO)

**Services**
```
https://console.aws.amazon.com/<service>/

CloudWatch Logs
https://console.aws.amazon.com/cloudwatch/home#logs
```

**EC2**
```
https://console.aws.amazon.com/ec2/
https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances
```

**Region**
```
https://console.aws.amazon.com/ec2/v2/home?region=us-east-1

VPC
https://console.aws.amazon.com/vpc/home?region=us-west-2#subnets
```

## How to Access an AWS EC2 Instance
Amazon EC2 (Elastic Compute Cloud) lets you run virtual servers in the AWS cloud.

**Prerequisites**
Before you can access an EC2 instance, you need:
- An AWS account
- A running EC2 instance
- A key pair (created when launching the instance)
- The instance’s public IP address or public DNS name
- Proper security group rules allowing access (SSH or RDP)

---

**Accessing a Linux EC2 Instance (SSH)**
Linux instances are typically accessed using SSH.
```bash
ssh -i key.pem user@host
```

#### 1. Check Security Group Rules
Ensure the security group allows inbound SSH traffic:
- Protocol: TCP
- Port: 22
- Source: Your IP address

#### 2. Locate Your Key Pair
You’ll need the private key file (.pem) you downloaded when creating the instance.
Set correct permissions:
```bash
chmod 400 my-key.pem
```

#### 3. Connect Using SSH
Use the instance’s public IP or DNS name.
Example:
```bash
ssh -i my-key.pem ec2-user@<public-ip>
```
> Common default usernames:
> - Amazon Linux: ec2-user
> - Ubuntu: ubuntu
> - RHEL: ec2-user
> - CentOS: centos

---

**Accessing a Windows EC2 Instance (RDP)**
Windows instances use Remote Desktop Protocol (RDP).

#### 1. Allow RDP in Security Group
Inbound rule:
- Protocol: TCP
- Port: 3389
- Source: Your IP address

#### 2. Get the Administrator Password
In the EC2 console:
Select the instance
1. Click Connect
2. Choose RDP Client
3. Upload your .pem key to decrypt the password

#### 3. Connect via Remote Desktop
Use:
- Public IP or DNS name
- Username: Administrator
- Decrypted password

> On most systems, use the built-in Remote Desktop client.

---

**Using AWS EC2 Instance Connect**
For Amazon Linux instances, AWS provides EC2 Instance Connect, which lets you connect via the browser or CLI without managing SSH keys locally.
Requirements:
- Instance must allow port 22
- Instance must support EC2 Instance Connect
- IAM permissions must be configured

**Common Troubleshooting Tips**
- Connection timeout: Check security group and network ACLs
- Permission denied (SSH): Verify username and key file permissions
- No public IP: Instance may be in a private subnet (use a bastion host or VPN)
- Stopped instance: Start it before connecting

---

## How to Generate Public and Private Keys to Access an AWS EC2 Instance
AWS EC2 uses public-key cryptography to securely access instances. Instead of passwords, you authenticate using a key pair, which consists of:
- Private key – kept securely on your local machine
- Public key – stored on the EC2 instance by AWS
> AWS uses these keys to verify your identity when you connect

### Option 1: Generate a Key Pair Using the AWS Console
**Steps**
1. Sign in to the AWS Management Console
2. Go to EC2 → Key Pairs
3. Click Create key pair
4. Enter:<br/>
&nbsp;&nbsp;&nbsp;&nbsp;- Name (e.g., my-ec2-key)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;- Key pair type: RSA<br/>
&nbsp;&nbsp;&nbsp;&nbsp;- Private key format:<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a. .pem (Linux/macOS/WSL)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;b. .ppk (PuTTY on Windows)<br/>
5. Click Create key pair

AWS will:
- Generate both keys
- Automatically store the public key
- Download the private key to your computer (only once)

> ⚠️ Important: If you lose the private key, AWS cannot recover it.

### Option 2: Generate a Key Pair Locally
You can generate keys yourself and upload the public key to AWS.

**Generate Keys Using SSH**
```bash
ssh-keygen -t rsa -b 4096 -f my-ec2-key
```

This creates:
- my-ec2-key → private key
- my-ec2-key.pub → public key

**Upload Public Key to AWS**
1. Go to EC2 → Key Pairs
2. Click Import key pair
3. Enter a name
4. Paste contents of my-ec2-key.pub
5. Click Import
> Now AWS can use your public key when launching instances.

**Using the Key Pair When Launching an EC2 Instance**
When creating an EC2 instance:
1. In Key pair (login) section
2. Select:<br/>
&nbsp;&nbsp;&nbsp;&nbsp;- An existing key pair or<br/>
&nbsp;&nbsp;&nbsp;&nbsp;- Create a new one<br/>
3. Launch the instance
> AWS installs the public key on the instance automatically.

**File Permissions for Private Keys (Linux/macOS)**
SSH will reject insecure key files.
```bash
chmod 400 my-ec2-key.pem
```

### Best Practices
- Never commit private keys to Git
- Store keys in a secure password manager or vault
- Use one key per environment (dev, staging, prod)
- Rotate keys regularly
- Prefer AWS SSM Session Manager for production access














