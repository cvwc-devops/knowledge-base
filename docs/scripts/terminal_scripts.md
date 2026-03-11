# open each session in a separate terminal tab.

```bash
#!/bin/bash
/opt/synner/synner --action register $USER
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11/bin:/usr/openwin/bin
clear
date;hostname

for x in ia4 ia5 ia3 ia2 on2 on3 on8 lon
do
   echo $x
   gnome-terminal --tab -- bash -c "ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null $USER@base-hostname-1-${x}; exec bash"
done
```

## using tmux
```bash
#!/bin/bash
/opt/synner/synner --action register $USER
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11/bin:/usr/openwin/bin
clear
date;hostname

# Start a new tmux session
tmux new-session -d -s mysession

for x in ia4 ia5 ia3 ia2 on2 on3 on8 lon
do
   echo $x
   # Create a new window in the tmux session for each host
   tmux new-window -t mysession: -n "$x" "ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null $USER@base-hostname-1-${x}; bash"
done

# Attach to the tmux session
tmux attach-session -t mysession
```

Explanation:
- tmux new-session -d -s mysession: This starts a new tmux session named mysession in detached mode.
- tmux new-window -t mysession: -n "$x" "command": This creates a new window in the mysession tmux session with the name $x and runs the specified command.
- tmux attach-session -t mysession: This attaches to the mysession tmux session, allowing you to see the windows that were created.

## alt tmux
```bash
#!/bin/bash
/opt/synner/synner --action register $USER
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11/bin:/usr/openwin/bin
clear
date;hostname

# Start a new tmux session
tmux new-session -d -s mysession

for x in ia4 ia5 ia3 ia2 on2 on3 on8 lon
do
   echo $x
   # Create a new window in the tmux session for each host
   tmux new-window -t mysession: -n "$x" "ssh -o stricthostkeychecking=no -o UserKnownHostsFile=/dev/null $USER@base-hostname-1-${x}; bash"
done
```

Explanation:
- tmux new-session -d -s mysession: Creates a new tmux session in the background.
- tmux new-window -t mysession: -n "$x" "command": Adds a new window to the session for each SSH connection.

## tmux - one liner
```bash
tmux new-session -d -s mysession && for i in {1..6}; do tmux new-window -t mysession: -n "window$i" "echo 'This is window $i'; bash"; done && tmux select-window -t mysession:1 && tmux attach-session -t mysession
```

## tmux commands:
- Switch to the next window:
```
Ctrl+b n
```
> This command moves to the next window.
- Switch to the previous window:
```
Ctrl+b p
```
> This command moves to the previous window.
- Switch to a specific window by number:
```
Ctrl+b <number>
```
> Replace <number> with the window number (e.g., Ctrl+b 1 to go to window 1).
- List all windows:
```
Ctrl+b w
```

> Each of these commands is preceded by Ctrl+b, the default prefix key in tmux.

