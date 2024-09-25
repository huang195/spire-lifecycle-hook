## Unix domain socket

In case we would like to have a top half and bottom half of lifecycle code, e.g., to
increase responsiveness of pod startup time, we could use a unix domain socket to
communicate work between the two halves. 
