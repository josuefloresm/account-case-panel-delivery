/**
 * Extracts the messages of a failed Lightning Data Service save that were written for
 * the user: validation rules and addError() calls, which the platform reports with the
 * FIELD_CUSTOM_VALIDATION_EXCEPTION code.
 *
 * Every other error code (trigger failures such as CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY,
 * access errors, network or JavaScript errors) is dropped, so the caller shows a
 * controlled custom label and no raw exception text reaches the screen.
 */
const DISPLAYABLE_ERROR_CODES = new Set(['FIELD_CUSTOM_VALIDATION_EXCEPTION']);

export function reduceSaveErrors(errors) {
    const list = Array.isArray(errors) ? errors : [errors];
    const messages = list
        .filter(Boolean)
        .flatMap(errorItemsOf)
        .filter((item) => DISPLAYABLE_ERROR_CODES.has(item?.errorCode))
        .map((item) => item.message)
        .filter(Boolean);
    return [...new Set(messages)];
}

function errorItemsOf(error) {
    const body = error.body;
    if (Array.isArray(body)) {
        return body;
    }
    if (body?.output) {
        const pageErrors = body.output.errors ?? [];
        const fieldErrors = Object.values(body.output.fieldErrors ?? {}).flat();
        return [...pageErrors, ...fieldErrors];
    }
    return [];
}
