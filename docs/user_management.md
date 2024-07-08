<!-- Space: NPG -->
<!-- Parent: Tracking -->
<!-- Title: User Management -->

<!-- Macro: :box:([^:]+):([^:]*):(.+):
     Template: ac:box
     Icon: true
     Name: ${1}
     Title: ${2}
     Body: ${3} -->

:box:info:Note:This page is automatically generated; any edits will be overwritten:

###### Repository information

<!-- Include: includes/repo-metadata.md -->

# How to give users the permissions to set up a run 
Users that use the NPG pipeline could ask, through a ticket, to be 
granted some permissions to set up runs.

There are following the steps to grant permissions using the
tracking web pages:

1. Add a `user`. From the option bar:
    
    * `Admin` -> `New User`    
    * Enter the username -> `New User` (next to the textbox)
    
    If the user is already present it will display the duplicate 
    error message as expected.

1.  Add a `user` to an `user group`

    To give specific permissions there are different groups. 
    The most common are `loaders` and `annotators`. 
    The former is needed to load runs and the latter to add annotations. 
    Those are enough when asked to give users some permissions 
    to create new runs.
    
    * `Admin` -> `Add user to Usergroup`
    * Choose the user name from the left menu
    * Choose `loaders` from the right menu -> `Add to Usergroup`
    * Choose again the user name from the left menu
    * Choose `annotators` from the right menu -> `Add to Usergroup`
    