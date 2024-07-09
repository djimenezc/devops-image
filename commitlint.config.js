module.exports = {
  extends: ['@commitlint/config-conventional'],
  parserPreset: {
    parserOpts: {
      issuePrefixes: ['EUDEV-'],
    },
  },
  rules: {
    'references-empty': [2, 'never'],
  },
};
