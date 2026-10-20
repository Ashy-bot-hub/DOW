/* WB-GUARD: removeChild unmount guard
 *
 * Purpose
 *   WorkDaddy injects UI/DOM helpers into the WorkBuddy renderer. During a
 *   conversation (task) switch, React may call removeChild for a node whose
 *   parent has already changed, which throws:
 *     NotFoundError: Failed to execute 'removeChild' on 'Node'
 *   That exception is caught by the error boundary and replaces the whole
 *   page with the "出错了" screen.
 *
 *   This guard wraps Node.prototype.removeChild and turns that specific
 *   mismatch into a silent no-op, so the error boundary is never reached.
 *
 * Behaviour
 *   - Only the "child is not a child of this node" case is skipped.
 *   - Every skip is counted in window.__wbRCGuarded for diagnostics.
 *   - Any other removeChild path keeps its original semantics.
 *
 * Side effect
 *   A skipped removal can leave an orphaned DOM node behind (minor visual
 *   artifacts possible). Roll back by restoring inject.js.bak-wbguard.
 *
 * Loading
 *   Paste at the very top of WorkDaddy scripts/inject.js, or run
 *   install-wb-guard.ps1 which does this automatically.
 */
(function () {
  if (typeof Node === 'undefined' || !Node.prototype || !Node.prototype.removeChild) return;
  if (window.__wbRCGuardInstalled) return;
  window.__wbRCGuardInstalled = true;
  window.__wbRCGuarded = 0;
  var orig = Node.prototype.removeChild;
  Node.prototype.removeChild = function (child) {
    try {
      if (!child || child.parentNode !== this) { window.__wbRCGuarded++; return child; }
      return orig.call(this, child);
    } catch (e) {
      window.__wbRCGuarded++;
      return child;
    }
  };
})();
