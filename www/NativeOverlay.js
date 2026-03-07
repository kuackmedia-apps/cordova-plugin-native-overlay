var exec = require('cordova/exec');

var NativeOverlay = {
    show: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'show', []);
    },
    hide: function (success, error) {
        exec(success || function () {}, error || function () {}, 'NativeOverlay', 'hide', []);
    },
};

module.exports = NativeOverlay;
