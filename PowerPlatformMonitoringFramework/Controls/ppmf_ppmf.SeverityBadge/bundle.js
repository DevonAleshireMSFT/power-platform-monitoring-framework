/*
 * ATTENTION: The "eval" devtool has been used (maybe by default in mode: "development").
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
var pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad;
/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./SeverityBadge/index.ts"
/*!********************************!*\
  !*** ./SeverityBadge/index.ts ***!
  \********************************/
(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

eval("{__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   SeverityBadge: () => (/* binding */ SeverityBadge)\n/* harmony export */ });\nvar SEVERITY_MAP = {\n  1: {\n    label: \"Info\",\n    bg: \"#EFF6FC\",\n    color: \"#0F6CBD\"\n  },\n  2: {\n    label: \"Warning\",\n    bg: \"#FFF8F0\",\n    color: \"#835B00\"\n  },\n  3: {\n    label: \"Critical\",\n    bg: \"#FDE7E9\",\n    color: \"#C50F1F\"\n  },\n  4: {\n    label: \"Unknown\",\n    bg: \"#F3F2F1\",\n    color: \"#616161\"\n  }\n};\nclass SeverityBadge {\n  init(context, notifyOutputChanged, state, container) {\n    this._container = container;\n  }\n  updateView(context) {\n    var _a;\n    this._container.innerHTML = \"\";\n    var raw = context.parameters.severityValue.raw;\n    if (raw === null || raw === undefined) return;\n    var style = (_a = SEVERITY_MAP[raw]) !== null && _a !== void 0 ? _a : {\n      label: String(raw),\n      bg: \"#F3F2F1\",\n      color: \"#616161\"\n    };\n    var badge = document.createElement(\"span\");\n    badge.className = \"ppmf-badge\";\n    badge.textContent = style.label;\n    badge.style.backgroundColor = style.bg;\n    badge.style.color = style.color;\n    this._container.appendChild(badge);\n  }\n  getOutputs() {\n    return {};\n  }\n  destroy() {\n    this._container.innerHTML = \"\";\n  }\n}\n\n//# sourceURL=webpack://pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad/./SeverityBadge/index.ts?\n}");

/***/ }

/******/ 	});
/************************************************************************/
/******/ 	// The require scope
/******/ 	var __webpack_require__ = {};
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module can't be inlined because the eval devtool is used.
/******/ 	var __webpack_exports__ = {};
/******/ 	__webpack_modules__["./SeverityBadge/index.ts"](0,__webpack_exports__,__webpack_require__);
/******/ 	pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad = __webpack_exports__;
/******/ 	
/******/ })()
;
if (window.ComponentFramework && window.ComponentFramework.registerControl) {
	ComponentFramework.registerControl('ppmf.SeverityBadge', pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad.SeverityBadge);
} else {
	var ppmf = ppmf || {};
	ppmf.SeverityBadge = pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad.SeverityBadge;
	pcf_tools_652ac3f36e1e4bca82eb3c1dc44e6fad = undefined;
}