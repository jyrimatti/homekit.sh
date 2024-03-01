/**
 * Extension to persist input values across page loads,
 * either to
 * 1) sessionStorage
 * 2) localStorage
 * 3) URL query string
 * 4) URL fragment
 * 5) cookie
 * 6) http
 * 
 * Specify the store with attribute
 * 1) persist-fields-session
 *    - value is store key
 * 2) persist-fields-local
 *    - value is store key
 * 3) persist-fields-query
 *    - if value is 'indexed', the input values will be stored in the
 *      query as just values (without keys) separated by '&'
 * 4) persist-fields-fragment
 *    - if value is 'indexed', the input values will be stored in the
 *      fragment as just values (without keys) separated by '#'
 * 5) persist-fields-cookie
 *    - value is cookie options, e.g. 'path=/;max-age=31536000'
 * 6) persist-fields-http
 *    - value is the base URL to GET the data from and PUT the data to.
 *      "name" is concatenated to the base URL to form the full URL.
 *  
 * All nested 
 *   1) inputs having 'name' attribute and
 *   2) elements having 'persist-fields-name' attribute (e.g. a contenteditable div)
 * will be persisted, expect if they are children of 'hx-ext="ignore:persist-fields"'.
 * 
 * To clear the persisted fields and restore inputs to their default values,
 * dispatch the 'htmx:persistFieldsClear' event:
 * <button onclick="htmx.trigger(this, 'htmx:persistFieldsClear')">restore defaults</button>
 */
(function() {
    function storageAvailable(type) {
        if (type == 'queryStorage' || type == 'fragmentStorage' || type == 'cookieStorage' || type == 'httpStorage') {
            return true;
        }

        // https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API/Using_the_Web_Storage_API
        let storage;
        try {
          storage = window[type];
          const x = "__storage_test__";
          storage.setItem(x, x);
          storage.removeItem(x);
          return true;
        } catch (e) {
          return (
            e instanceof DOMException &&
            // everything except Firefox
            (e.code === 22 ||
              // Firefox
              e.code === 1014 ||
              // test name field too, because code might not be present
              // everything except Firefox
              e.name === "QuotaExceededError" ||
              // Firefox
              e.name === "NS_ERROR_DOM_QUOTA_REACHED") &&
            // acknowledge QuotaExceededError only if there's something already stored
            storage &&
            storage.length !== 0
          );
        }
    }

    // Unescape some useless escapes to make url cleaner
    function urlParamsToString(params) {
        return (params === undefined  ? '' :
                Array.isArray(params) ? params.join('') 
                                      : params.toString())
            .replaceAll('%2C',',')
            .replaceAll('%3A',':');
    }

    function distinct(value, index, array) {
        return array.indexOf(value) === index;
    }

    function isCheckable(elem) {
        return elem.type === 'checkbox' || elem.type === 'radio';
    }

    function allForName(scope, name) {
        let self = name == scope.getAttribute('name') || name == scope.getAttribute('persist-fields-name') ? [scope] : [];
        return self.concat([...scope.querySelectorAll('[name="'+name+'"'), ...scope.querySelectorAll('[persist-fields-name="'+name+'"]')].filter(x => !x.disabled));
    }

    // Returns the current value of the given element.
    function currentValue(elem) {
        return isCheckable(elem)                                       ? [elem.checked] :
               elem.tagName === 'SELECT'                               ? [...elem.selectedOptions].map(x => x.value) :
               elem.tagName === 'INPUT' || elem.tagName === 'TEXTAREA' ? [elem.value] :
                                                                         [elem.innerText];
    }

    // Returns the default value of the given element.
    function defaultValue(elem) {
        return isCheckable(elem)                                       ? [elem.defaultChecked] :
               elem.tagName === 'SELECT'                               ? [...elem.options].filter(x => x.defaultSelected).map(x => x.value) :
               elem.tagName === 'INPUT' || elem.tagName === 'TEXTAREA' ? [elem.defaultValue] :
                                                                         [elem.innerText];
    }

    // Values/defaults for all fields named 'name'
    function resolve(scope, name, f) {
        let all = allForName(scope, name);
        let checkables = all.filter(isCheckable).filter(x => f(x)[0]).map(x => x.value).join(",");
        let others = all.filter(x => !isCheckable(x)).flatMap(f);
        return [checkables].filter(x => x != '').concat(others);
    }

    // Returns all input descendants (including self) of the given element, which are not ignored by hx-ext="ignore:persist-fields".
    function getFields(elem) {
        if (["INPUT","TEXTAREA","SELECT"].includes(elem.tagName) && elem.hasAttribute('name') ||
                elem.hasAttribute('persist-fields-name')) {
            return [elem];
        } else {
            var fields = []
            elem.querySelectorAll("input[name], textarea[name], select[name], [persist-fields-name]").forEach(x => {
                api.withExtensions(x, function (ext) {
                    if (ext._ext_persist_fields) {
                        fields.push(x);
                    }
                });
            });
            return fields;
        }
    }

    function readQueryOrFragment(storageKey, separator, data) {
        if (typeof storageKey === 'number') {
            var values = data.trim().length == 0 ? [] : data.split(separator);
            return storageKey < values.length ? [values[storageKey]] : undefined;
        } else if (typeof storageKey === 'string') {
            let params = new URLSearchParams(data);
            let ret = params.has(storageKey) ? params.getAll(storageKey) : undefined;
            return Array.isArray(ret) && ret.length == 1 && ret[0] === "" ? [] : ret;
        } else {
            return data;
        }
    }

    // Read the value under 'index' from 'storage'.
    function readStorage(storage, storageKey, callback) {
        if (storage == 'query') {
            callback(readQueryOrFragment(storageKey, '&', window.location.search.substring(1)));
        } else if (storage == 'fragment') {
            callback(readQueryOrFragment(storageKey, '#', window.location.hash.substring(1)));
        } else if (storage == 'cookie') {
            let params = document.cookie
                                 .split("; ")
                                 .map(x => {
                                    let parts = x.split("=");
                                    let ret = {};
                                    ret[parts[0]] = parts[1] === undefined ? undefined : parts[1].split(',').map(decodeURIComponent);
                                    return ret;
                                 }).reduce(((r, c) => Object.assign(r, c)), {});
            callback(storageKey ? (params[storageKey] ? params[storageKey] : undefined) : params);
        } else if (storage == 'session') {
            callback(JSON.parse(sessionStorage.getItem(storageKey)) || {});
        } else if (storage == 'local') {
            callback(JSON.parse(localStorage.getItem(storageKey)) || {});
        } else if (storage == 'http') {
            let req = new XMLHttpRequest();
            req.addEventListener("load", function() { callback([this.responseText]); });
            req.open("GET", storageKey);
            req.send();
        }
    }

    function modifyQueryOrFragment(storageKey, separator, data, contents) {
        if (typeof storageKey === 'number') {
            const values = data.substring(1).split(separator);
            while (values.length <= storageKey) {
                values.push('');
            }
            values[storageKey] = urlParamsToString(contents);
            return values.join(separator);
        } else {
            let params = new URLSearchParams(data.substring(1));
            params.delete(storageKey);
            if (contents.length == 0) {
                params.append(storageKey, "");
            } else {
                contents.forEach(x => params.append(storageKey, urlParamsToString(x)));
            }
            return params.toString();
        }
    }

    // Save 'contents' to 'storage'.
    function saveStorage(storage, contents, storageKey, cookieOptions) {
        if (storage === 'query') {
            let data = modifyQueryOrFragment(storageKey, '&', window.location.search, contents);
            if (data !== window.location.search.substring(1)) {
                history.replaceState(null, null, window.location.protocol + '//' + window.location.host + window.location.pathname + '?' + data + window.location.hash);
            }
        } else if (storage === 'fragment') {
            let data = modifyQueryOrFragment(storageKey, '#', window.location.hash, contents);
            if (data !== window.location.hash.substring(1)) {
                history.replaceState(null, null, window.location.protocol + '//' + window.location.host + window.location.pathname + window.location.search + '#' + data);
            }
        } else if (storage === 'cookie') {
            if (contents) {
                document.cookie = storageKey + '=' + contents.map(encodeURIComponent).join(',') + ';' + cookieOptions;
            } else {
                document.cookie = storageKey + '=;max-age=0'; // delete cookie
            }
        } else if (storage === 'session') {
            if (contents === undefined) {
                sessionStorage.removeItem(storageKey);
            } else {
                sessionStorage.setItem(storageKey, JSON.stringify(contents));
            }
        } else if (storage === 'local') {
            if (contents === undefined) {
                localStorage.removeItem(storageKey);
            } else {
                localStorage.setItem(storageKey, JSON.stringify(contents));
            }
        } else if (storage === 'http') {
            let req = new XMLHttpRequest();
            if (contents === undefined) {
                req.open("GET", storageKey);
                req.send();
            } else {
                req.open("PUT", storageKey);
                req.send(contents);
            }
        }
    }

    function deleteContent(name, contents) {
        if (contents) {
            if (contents.delete) {
                contents.delete(name);
            } else if (contents[name] !== undefined) {
                delete contents[name];
            }
        }
        return contents;
    }

    // Restore the default values for all fields under 'persistScope'
    function clear(storage, persistScope, storageKey) {
        let cb = contents => {
            if (persistScope) {
                persistScope.querySelectorAll('[data-persist-fields-initialized]').forEach(x => {
                    contents = deleteContent(x.getAttribute('name'), contents);

                    // set value to stored default
                    if (isCheckable(x)) {
                        x.checked = x.getAttribute('data-persist-fields-initialized') === 'true';
                    } else {
                        x.value = x.getAttribute('data-persist-fields-initialized');
                    }
                });
            }
            saveStorage(storage, contents, storageKey);
        };
        if (storageKey) {
            cb()
        } else {
            readStorage(storage, undefined, cb);
        }
    }

    function setValue(scope, child, name, values) {
        if (values !== undefined) {
            if (isCheckable(child) && !child.hasAttribute('readonly')) {
                child.checked = values.flatMap(x => x.split(",")).includes(child.value);
            } else if (child.tagName === 'SELECT' && !child.hasAttribute('readonly')) {
                [...child.options].forEach(x => x.selected = values.flatMap(x => x.split(",")).includes(x.value));
            } else if (child.tagName === 'INPUT' || child.tagName === 'TEXTAREA') {
                let all = allForName(scope, name);
                if (all.length === 1) {
                    if (!child.hasAttribute('readonly')) {
                        child.value = values.length == 0 ? '' : values.join(',');
                    }
                } else {
                    // multiple inputs with the same name -> set value only for the input at the correct position
                    let position = all.indexOf(child);
                    let value = getValueAtPosition(all, values, position);
                    if (value !== undefined && !child.hasAttribute('readonly')) {
                        child.value = value;
                    }
                }
            } else {
                child.innerText = values.length == 0 ? '' : values.join('');
            }
        }
    }

    function matchConstant(remaining, field) {
        if (field.hasAttribute('readonly')) {
            if (remaining.startsWith(field.getAttribute('value'))) {
                let currentPart = field.getAttribute('value');
                return [currentPart, remaining.substring(currentPart.length)];
            }
        }
        return undefined;
    }

    function matchConstantLength(remaining, field) {
        if (field.hasAttribute('minlength') && field.getAttribute('minlength') === field.getAttribute('maxlength')) {
            let currentPart = remaining.substring(0, parseInt(field.getAttribute('minlength')));
            return [currentPart, remaining.substring(currentPart.length)];
        }
        return undefined;
    }
    
    function matchPattern(remaining, field) {
        if (field.hasAttribute('pattern')) {
            let pattern = field.getAttribute('pattern');
            let matchResult = remaining.match(pattern.startsWith('^') ? pattern : '^' + pattern);
            if (matchResult !== null) {
                let currentPart = matchResult.length > 1 ? matchResult[1] : matchResult[0];
                return [currentPart, remaining.substring(currentPart.length)];
            }
        }
        return undefined;
    }

    function matchDateTime(remaining, field) {
        if (field.getAttribute('type') === 'datetime-local') {
            let matchResult = remaining.match('^[0-9]{1,4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}');
            if (matchResult !== null) {
                let currentPart = matchResult[0];
                return [currentPart, remaining.substring(currentPart.length)];
            }
        }
        return undefined;
    }

    function matchDate(remaining, field) {
        if (field.getAttribute('type') === 'date') {
            let matchResult = remaining.match('^[0-9]{1,4}-[0-9]{2}-[0-9]{2}');
            if (matchResult !== null) {
                let currentPart = matchResult[0];
                return [currentPart, remaining.substring(currentPart.length)];
            }
        }
        return undefined;
    }

    function matchTime(remaining, field) {
        if (field.getAttribute('type') === 'time') {
            // time
            let matchResult = remaining.match('^[0-9]{2}:[0-9]{2}(:[0-9]{2})?');
            if (matchResult !== null) {
                let currentPart = matchResult[0];
                return [currentPart, remaining.substring(currentPart.length)];
            }
        }
        return undefined;
    }

    function matchSelect(remaining, field) {
        if (field.tagName === 'SELECT') {
            let currentPart = remaining.split(',', 1)[0];
            return [currentPart, remaining.substring(currentPart.length + 1)];
        }
        return undefined;
    }

    function matchAll(remaining, field) {
        return [remaining, ''];
    }

    function matchField(remaining, field) {
        for (let i in fieldMatchers) {
            let ret = fieldMatchers[i](remaining, field);
            if (ret !== undefined) {
                return ret;
            }
        }
        return undefined;
    }

    function getValueAtPosition(all, values, position) {
        if (values.length == 0) {
            return '';
        } else if (values.length > 1) {
            return values[position];
        } else {
            let [currentPart,_] = all.slice(0, position+1)
                                     .reduce(([_,remaining], field) => matchField(remaining, field), [undefined, values[0]]);
            return currentPart;
        }
    }

    function getName(field) {
        return field.getAttribute('name') || field.getAttribute('persist-fields-name');
    }

    function handleStorage(scope, storage, field, indexOrCookieOptions) {
        let name = getName(field);
        let storageKey = storage === 'cookie'                ? name :                 // cookies can only by keyed by field name.
                         storage === 'http'                  ? indexOrCookieOptions + name :
                         indexOrCookieOptions !== undefined  ? indexOrCookieOptions : // if using localStore/sessionStore or indexed storage, use the index
                                                               name;

        // have to read defaults on initialization since browsers change them when value is changed programmatically
        let defaults = resolve(scope, name, defaultValue);

        // initialize the field with the value from storage
        readStorage(storage, storageKey, currentValues => {
            setValue(scope, field, name, storage === 'local' || storage === 'session' ? currentValues[name] : currentValues);
        });

        // mark element as initialized, to prevent multiple initializations, and to store original value
        field.setAttribute("data-persist-fields-initialized", defaultValue(field).join(','));

        // must process before adding triggers, otherwise Htmx will deinit the element clearing listeners
        htmx.process(field);

        api.getTriggerSpecs(field).forEach(triggerSpec => {
            let nodeData = api.getInternalData(field);
            api.addTriggerHandler(field, triggerSpec, nodeData, (elt, evt) => {
                if (htmx.closest(elt, htmx.config.disableSelector)) {
                    return;
                }
                let newValues = resolve(scope, name, currentValue);
                readStorage(storage, storageKey, current => {
                    let cur = deleteContent(name, current);
                    if (JSON.stringify(newValues) != JSON.stringify(defaults) || field.required) {
                        if (cur && !Array.isArray(cur)) {
                            cur[name] = newValues;
                        } else {
                            cur = newValues;
                        }
                    }

                    saveStorage(storage, cur, storageKey, indexOrCookieOptions);
                });
            });
        });
    }

    let storages = ['session', 'local', 'query', 'fragment', 'cookie', 'http'];

    var api;
    var fieldMatchers;

    htmx.defineExtension('persist-fields', {
        _ext_persist_fields: true,

        init: function (internalAPI) {
            api = internalAPI;
            fieldMatchers = [matchConstant, matchConstantLength, matchPattern, matchDateTime, matchDate, matchTime, matchSelect, matchAll];
        },
        
        onEvent: function (name, evt) {
            if (name === "htmx:persistFieldsClear") {
                storages.forEach(storageType => {
                    let persistScope = htmx.closest(evt.detail.elt, '[persist-fields-' + storageType +']');
                    if (persistScope && storageAvailable(storageType + 'Storage')) {
                        if (persistScope.getAttribute('persist-fields-' + storageType) == 'indexed') {
                            clear(storageType);
                        } else {
                            clear(storageType, persistScope, persistScope.getAttribute('persist-fields-' + storageType));
                        }
                    }
                });
            } else if (name === "htmx:afterProcessNode") {
                let availableStorages = storages.filter(x => storageAvailable(x + 'Storage'));
                let selectors = availableStorages.map(x => '[persist-fields-' + x + ']').join(',');
                getFields(evt.detail.elt).filter(e => !e.hasAttribute('data-persist-fields-initialized'))
                                         .forEach(field => {
                    let persistScope = htmx.closest(field, selectors);
                    let storageType = availableStorages.find(x => persistScope.hasAttribute('persist-fields-' + x));
                    let indexOrCookieOptions = persistScope.getAttribute('persist-fields-' + storageType);
                    if (indexOrCookieOptions === 'indexed') {
                        let distinctNames = getFields(persistScope).map(getName).filter(distinct);
                        indexOrCookieOptions = distinctNames.indexOf(getName(field));
                    } else if (indexOrCookieOptions === '' || storageType === 'query' || storageType === 'fragment') {
                        indexOrCookieOptions = undefined;
                    }
                    handleStorage(persistScope, storageType, field, indexOrCookieOptions);
                });
            }
        }
    });
})();
