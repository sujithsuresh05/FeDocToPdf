# Captured API responses

Real responses from a running `BeDocToPdf`, used by `test/api_contract_test.dart`
so that a renamed or removed server field fails in CI rather than at the
operator's first tap.

All data is synthetic: the backend's own committed
`tests/fixtures/payslips.docx` (3 recipients x 2 pages) and a made-up staff
sheet. No real names or phone numbers.

## Regenerating

In the backend repo:

```sh
cat > /tmp/recips.csv <<'CSV'
key,name,phone
EMP-1001,Asha Menon,9442302726
EMP-1002,Rahul Verma,9388844484
EMP-1003,Grace Fernandes,"Mob: 8086006942, 8086006941, email: grace@example.com"
CSV

PORT=4020 STORAGE_DIR=/tmp/contract/storage \
  PUBLIC_BASE_URL=http://127.0.0.1:4020 npm start &

curl -s localhost:4020/api/capabilities -o capabilities.json
curl -s -X POST localhost:4020/api/analyse \
  -F "document=@tests/fixtures/payslips.docx" -o analyse.json
curl -s -X POST localhost:4020/api/jobs \
  -F "document=@tests/fixtures/payslips.docx;filename=Payslips.docx" \
  -F "recipients=@/tmp/recips.csv;filename=staff.csv" \
  -F "splitMode=section" -F "marker=RECIPIENT:" -F "matchBy=key" \
  -F "filenamePattern=Payslip-{{key}}" \
  -F "messageTemplate=Hi {{name}}, your payslip is attached." -o create.json
# then, once status is ready:
curl -s localhost:4020/api/jobs/<id> -o job.json
curl -s -X POST localhost:4020/api/jobs/<id>/parts/1/sent \
  -H 'Content-Type: application/json' -d '{"sent":true}' -o sent.json
```

Copy the five files into this directory. The third recipient's cell is
deliberately messy: it checks that phone extraction survives the round trip.
