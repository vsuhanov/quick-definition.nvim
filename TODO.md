- ☐ figure out development approach, once the plugin is installed it's a bit annoying to reload the plugin
- ✓ ~~allow to quick exit on esc or q (or custom mapping) inside the quick definition window~~
        - ✓ ~~this needs to be added to each buffer that enters this window and be removed on BufLeave event?~~ 
        need to investigate if it's safe to write the buffer if there are any changes - should not update files outside of the worskapce but it's hard to tell which file is
- ☐ check if buffer already has mappings for the desired keys, if they exist don't add new ones. 
- ☐ allow configuring custom keymaps for exit/enter
- ☐ add a README.md file with description how to use it
- ☐ make it so if there is no definition attempt to go to declaration/implementation until something pops
- ✓ ~~show the name/path to the file in the quick definition window~~
- ☐ allow to quickly jump to editing of the file in the window where it all started 
- ✓ ~~extract key bindings into my own configuration~~
- ✓ ~~configure my nvim to use deployed version~~
- ☐ add an autosave option so that the changes in quick-def buffer are saved on leave 
- ☐ if there are multiple definitions open all of them in multiple floating windows. provide a property to specify how many items to open this way
