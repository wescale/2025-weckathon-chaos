import http from 'k6/http';
import { sleep } from 'k6';

const TARGET_URL = __ENV.URL || 'http://localhost:8080';

export let options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 35, // configurable via --env VUS
  duration: __ENV.DURATION || '1m', // configurable via --env DURATION
};

export default function () {
  http.get(TARGET_URL);
  sleep(0.5);
}
