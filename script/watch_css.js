import { watch } from "node:fs"
import { join } from "node:path"

const stylesheets = join(import.meta.dir, "..", "app", "assets", "stylesheets")
let build
let queued = false

function buildCss() {
  if (build) {
    queued = true
    return
  }

  build = Bun.spawn([ "bun", "run", "build:css" ], { stdout: "inherit", stderr: "inherit" })
  build.exited.then((status) => {
    build = undefined
    if (status !== 0) process.exitCode = status

    if (queued) {
      queued = false
      buildCss()
    }
  })
}

const watcher = watch(stylesheets, { recursive: true }, (_event, path) => {
  if (path?.endsWith(".scss")) buildCss()
})

function stop() {
  watcher.close()
  if (build) {
    build.kill()
    build.exited.finally(() => process.exit())
  } else {
    process.exit()
  }
}

process.on("SIGINT", stop)
process.on("SIGTERM", stop)

buildCss()
