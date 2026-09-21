import { AxiosError, AxiosHeaders } from 'axios';
import { Platform } from 'react-native';

import { toAppError } from '../src/utils/errors';

const config = { headers: new AxiosHeaders(), data: new FormData() };

describe('toAppError — oversized uploads', () => {
  const originalOS = Platform.OS;
  afterEach(() => {
    Platform.OS = originalOS;
  });

  it('explains a proxy 413 instead of "Something went wrong"', () => {
    const error = new AxiosError('Request failed', 'ERR_BAD_REQUEST', config, null, {
      status: 413,
      statusText: 'Request Entity Too Large',
      data: '<html><title>413 Request Entity Too Large</title></html>',
      headers: {},
      config,
    });

    const info = toAppError(error);
    expect(info.status).toBe(413);
    expect(info.message).toMatch(/too large/i);
  });

  it('on web, reports a CORS-hidden upload rejection as an upload problem, not offline', () => {
    Platform.OS = 'web';
    const error = new AxiosError('Network Error', 'ERR_NETWORK', config);

    expect(toAppError(error).message).toMatch(/rejected before it reached the server/i);
  });

  it('on native, ERR_NETWORK still means no connection', () => {
    Platform.OS = 'android';
    const error = new AxiosError('Network Error', 'ERR_NETWORK', config);

    expect(toAppError(error).message).toMatch(/no internet connection/i);
  });
});
