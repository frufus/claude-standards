module.exports = {
  forbidden: [
    {
      name: "components-do-not-touch-repositories",
      severity: "error",
      from: { path: "^src/components" },
      to: { path: "^src/repositories" },
    },
  ],
  options: { tsPreCompilationDeps: true, exclude: "node_modules" },
};
