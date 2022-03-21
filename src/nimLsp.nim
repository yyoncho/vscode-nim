import std/jsconsole
import platform/[vscodeApi, languageClientApi]

import platform/js/[jsNodeFs, jsNodePath, jsNodeCp]

from std/strformat import fmt
from tools/nimBinTools import getNimbleExecPath, getBinPath
from spec import ExtensionState

proc startLanguageServer(tryInstall: bool, state: ExtensionState) =
  let rawPath = getBinPath("nimls")
  if rawPath.isNil or not fs.existsSync(path.resolve(rawPath)):
    console.log("nimls not found on path")
    if tryInstall and not state.installPerformed:
      vscode.window.showInformationMessage("Unable to find nimls, trying to install it via 'nimble'")
      state.installPerformed = true
      discard cp.exec(
        # TODO change the url from yyoncho to nim-lang once it is merged to nim-lang
        getNimbleExecPath() & " install https://github.com/yyoncho/langserver --accept",
        ExecOptions{},
        proc(err: ExecError, stdout: cstring, stderr: cstring): void =
          console.log("Nimble install finished, checking if nimls is already present.")
          startLanguageServer(false, state))
    else:
      vscode.window.showInformationMessage("Unable to find/install `nimls`.")
  else:
    let nimls = path.resolve(rawPath);
    console.log(fmt"nimls found: {nimls}")
    console.log("Starting nimls.")
    let
      serverOptions = ServerOptions{
        run: Executable{command: nimls, transport: "stdio" },
        debug: Executable{command: nimls, transport: "stdio" }
      }
      clientOptions = LanguageClientOptions{
        documentSelector: @[cstring("nim")]
      }

    state.client = vscodeLanguageClient.newLanguageClient(
       cstring("nimls"),
       cstring("Nim Language Server"),
       serverOptions,
       clientOptions)
    state.client.start()

export startLanguageServer
