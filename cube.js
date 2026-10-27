// Kanso dashboard: a still cube that turns 90° only when asked, then rests square.

(function () {
  const scene = document.querySelector(".cube-scene");
  const cube = scene.querySelector(".cube");
  const facingOut = document.getElementById("cube-facing");
  const turnsOut = document.getElementById("cube-turns");

  // Turns are about the viewer's axes, so "right" always rolls the face in front of you right.
  // The orientation matrix only ever holds 0 / ±1, so it never drifts off square.
  const TURNS = {
    right: [[0, 0, 1], [0, 1, 0], [-1, 0, 0]],   // rotateY(90deg)
    left: [[0, 0, -1], [0, 1, 0], [1, 0, 0]],    // rotateY(-90deg)
    up: [[1, 0, 0], [0, 0, -1], [0, 1, 0]],      // rotateX(90deg)
    down: [[1, 0, 0], [0, 0, 1], [0, -1, 0]],    // rotateX(-90deg)
  };
  // Outward direction of each face before any turn (CSS: +x right, +y down, +z towards you).
  const FACES = {
    front: [0, 0, 1], back: [0, 0, -1], right: [1, 0, 0],
    left: [-1, 0, 0], top: [0, -1, 0], bottom: [0, 1, 0],
  };
  const START = [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
  let orient = START;
  let turns = 0;
  let turning = false;

  const multiply = (a, b) => a.map((row) => b[0].map((_, j) => row.reduce((sum, v, k) => sum + v * b[k][j], 0)));
  const apply = (m, v) => m.map((row) => row.reduce((sum, x, k) => sum + x * v[k], 0));

  const render = () => {
    const c = (j) => [orient[0][j], orient[1][j], orient[2][j], 0];   // matrix3d is column-major
    cube.style.transform = `rotateX(-22deg) rotateY(32deg) matrix3d(${[...c(0), ...c(1), ...c(2), 0, 0, 0, 1].join(",")})`;
    facingOut.textContent = Object.keys(FACES).find((f) => apply(orient, FACES[f])[2] === 1);
    turnsOut.textContent = turns;
  };

  // Ignore input while a turn is moving, so turns never pile up.
  const settle = () => {
    const ms = parseFloat(getComputedStyle(cube).transitionDuration) * 1000;
    if (ms > 0) {
      turning = true;
      setTimeout(() => { turning = false; }, ms);
    }
  };
  const turn = (dir) => {
    if (turning) return;
    orient = multiply(TURNS[dir], orient);
    turns += 1;
    render();
    settle();
  };
  const reset = () => {
    if (turning || orient === START) return;
    orient = START;
    turns = 0;
    render();
    settle();
  };

  // Which edge of the scene the pointer is nearest to.
  const edgeAt = (e) => {
    const r = scene.getBoundingClientRect();
    const dx = (e.clientX - r.left) / r.width - 0.5;
    const dy = (e.clientY - r.top) / r.height - 0.5;
    if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? "right" : "left";
    return dy > 0 ? "down" : "up";
  };

  render();
  scene.addEventListener("click", (e) => turn(edgeAt(e)));
  scene.addEventListener("pointermove", (e) => { scene.dataset.hover = edgeAt(e); });
  scene.addEventListener("pointerleave", () => { delete scene.dataset.hover; });
  document.querySelectorAll(".cube-btn").forEach((b) => b.addEventListener("click", () => turn(b.dataset.dir)));
  document.querySelector(".cube-reset").addEventListener("click", reset);

  // Arrow keys work anywhere on this page (the cube is the page's only job).
  document.addEventListener("keydown", (e) => {
    const dir = { ArrowRight: "right", ArrowLeft: "left", ArrowUp: "up", ArrowDown: "down" }[e.key];
    if (!dir || e.altKey || e.ctrlKey || e.metaKey) return;
    e.preventDefault();
    turn(dir);
  });
})();
