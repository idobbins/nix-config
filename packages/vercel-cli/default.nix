{ lib, buildNpmPackage, nodejs_22 }:

buildNpmPackage {
  pname = "vercel-cli";
  version = "59.11.7";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./package.json ./package-lock.json ];
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-Qz+zfcwO4BazABdO+rfwSP4lw3yyCMdXfeox4HjHRFI=";
  dontNpmBuild = true;

  meta = {
    description = "Vercel command-line interface";
    homepage = "https://vercel.com/docs/cli";
    license = lib.licenses.asl20;
    mainProgram = "vercel";
  };
}
