{
  description = "Godot game factory: pinned engine + headless render toolchain (NixOS, no GPU required)";

  # nixpkgs revision where pkgs.godot == 4.7.1-stable (matches the engine installed
  # on the factory host: `4.7.1.stable.nixpkgs`). Bump deliberately, re-run the
  # render probe (scripts/render_shot.sh) after any bump.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/f9420fcd14f603376af87f82d9b864ef605d60cf";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShell.${system} = pkgs.mkShell {
        packages = [
          pkgs.godot          # 4.7.1-stable engine + editor (headless-capable)
          pkgs.weston         # headless Wayland compositor — the ONLY working screenshot path here
          pkgs.mesa           # llvmpipe software Vulkan (lavapipe) + software GL
          pkgs.vulkan-loader
          pkgs.vulkan-tools   # vulkaninfo for backend assertions
          pkgs.bubblewrap     # sandboxing untrusted generated projects
          pkgs.git
          pkgs.gh
        ];
        shellHook = ''
          # Software Vulkan ICD for headless rendering (see docs/rendering.md)
          export MESA_ICD="${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.x86_64.json"
          export VK_DRIVER_FILES="$MESA_ICD"
          echo "godot-factory dev shell: godot $(godot --headless --version 2>/dev/null), ICD=$MESA_ICD"
        '';
      };
    };
}
