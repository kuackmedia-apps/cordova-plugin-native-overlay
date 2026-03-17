var exec = require('cordova/exec');

var NativeOverlay = {
    show: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'show', []);
    },
    hide: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'hide', []);
    },
    save: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'save', []);
    },
    showSaved: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'showSaved', []);
    },
    deleteSaved: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'deleteSaved', []);
    },
};

module.exports = NativeOverlay;