{ lib, ... } @ baseArgs:

{
  configRoot,
  optionTreeName ? "modules",
  modulesDir,
  specialArgs,
  ...
} @ args:

let
  # === Args ===

  # `configRoot`
  # A reference to the root `config` object of the whole configuration

  # `optionTreeName`
  # Name for the "root" of the option tree
  # All module options will be available under this name space
  # Example: `{modulesDir}/programs/shells/bash`
  # Becomes: `${optionTreeName}.programs.shells.bash`

  # `modulesDir`
  # Path to the directory to traverse and build the option tree from

  # `specialArgs`
  # All the arguments to pass to each of the modules in `modulesDir`

  # === Args ===



  # === Functions ===

  # Function to get the names of subdirectories in a directory
  getSubdirNames = dir : let
    dirContent = builtins.readDir dir;

    subDirNames = builtins.filter
      (contentName: # Filter to get directories that don't start with "_"
        (builtins.substring 0 1 contentName) != "_" &&
        dirContent.${contentName} == "directory"
      )
      (builtins.attrNames dirContent);

  in subDirNames;



  # Function to build a single module
  buildModule = { file, moduleArgs } : let
    fileExists = builtins.pathExists file;

    module = ({
      # Defaults
      options = {};
      config = {};
      imports = [];
    } // (if fileExists then (import file moduleArgs) else {}));

  in module;



  # Function to recursively traverse directory and build module tree
  buildModuleTree = { dir, moduleArgs, path } : let
    # Get the module in the current directory
    currentModule = buildModule {
      file = dir + "/default.nix";
      moduleArgs = moduleArgs // {
        # Pass the configuration for this module tree directly
        # avoiding infinite recursion by not reading from final config
        moduleConfig = lib.attrByPath path {} configRoot.${optionTreeName} or {};
      };
    };


    # Get submodules by the name of the folder they are in
    submodules = builtins.listToAttrs (map (dirName: {
      name = dirName;
      value = buildModuleTree {
        dir = dir + "/${dirName}";
        moduleArgs = moduleArgs;
        path = path ++ [ dirName ];
      };
    }) (getSubdirNames dir));

    # Get submodules' options by name of submodule
    submodulesOptions = builtins.mapAttrs 
      (_: v: v.options) 
      submodules;

    # Get submodules' configs in a list
    submodulesConfigs = builtins.attrValues (builtins.mapAttrs
      (_: v: v.config) 
      submodules);

    # Get submodules' imports in a flattened list
    submodulesImports = lib.flatten (builtins.attrValues (builtins.mapAttrs
      (_: v: v.imports)
      submodules));


    result = {
      # Use the current module's options and merge in the submodules' options as attrs
      options = currentModule.options // submodulesOptions;

      # Merge modules using lib.mkMerge for proper module system integration
      config = lib.mkMerge ([ currentModule.config ] ++ submodulesConfigs);

      # Collect all imports from the current module and submodules
      imports = currentModule.imports ++ submodulesImports;
    };

  in result;

  # === Functions ===




  # Create the module tree
  result = buildModuleTree {
    dir = modulesDir;
    moduleArgs = { inherit configRoot; } // specialArgs;
    path = [ ];
  };

in
{
  options.${optionTreeName} = result.options;
  config = result.config;
  imports = result.imports;
}