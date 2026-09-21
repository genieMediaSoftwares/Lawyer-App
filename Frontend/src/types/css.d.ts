/**
 * `global.css` is imported for its side effect by both entry points. Metro and
 * Vite each know what to do with it; TypeScript needs telling that a bare CSS
 * import is legal and carries no exports.
 */
declare module '*.css';
