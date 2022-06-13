# How to give users the permissions to set up a run 
Users that use the NPG pipeline could ask, through a ticket, to be 
granted some permissions to set up runs. Permissions should be granted 
only to those that are well known to the group. So, before adding users 
to a permission group, it is better to ask the team (if that person is 
unknown to you).

There are following the steps to grant permissions on the 
[SFWEB platform](http://sfweb.internal.sanger.ac.uk:9000/perl/npg):

1. Log in with your ```LDAP``` credentials to the website

1. Assure you are added to the ```admin group``` by looking in the 
    top-right corner below your name

1. Add a ```user```. From the option bar:
    
    * ```Admin``` -> ```New User ```    
    * Enter the username -> ```New User``` (next to the textbox)
    
    If the user is already present it will display the duplicate 
    error message as expected.

1.  Add a ```user``` to an ```user group```

    To give specific permissions there are different groups. 
    The most common are ```loaders``` and ```annotators```. 
    The former is needed to load runs and the latter to add annotations. 
    Those are enough when asked to give users some permissions 
    to create new runs.
    
    * ```Admin``` -> ```Add user to Usergroup```
    * Choose the user name from the left menu
    * Choose ```loaders``` from the right menu -> ```Add to Usergroup```
    * Choose again the user name from the left menu
    * Choose ```annotators``` from the right menu -> ```Add to Usergroup```
    