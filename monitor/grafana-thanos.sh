#!/bin/bash

oc create -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring-grafana
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: monitoring-grafana
spec:
  targetNamespaces:
  - monitoring-grafana
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: monitoring-grafana
  namespace: monitoring-grafana
spec:
  channel: v4
  installPlanApproval: Automatic
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

oc project monitoring-grafana

installReady=false
while [ "$installReady" != true ]
do
    installPlan=`oc get subscription.operators.coreos.com monitoring-grafana -n monitoring-grafana -o json | jq -r .status.installplan.name`
    if [ -z "$installPlan" ]
    then
        installReady=false
    else
        installReady=`oc get installplan -n monitoring-grafana "$installPlan" -o json | jq -r '.status|.phase == "Complete"'`
    fi

    if [ "$installReady" != true ]
    then
        sleep 5
    fi
done
installReady=false
while [ "$installReady" != true ]
do
    csv=`oc get subscription.operators.coreos.com monitoring-grafana -n monitoring-grafana -o json | jq -r .status.currentCSV`
    if [ -z "$csv" ]
    then
        installReady=false
    else
        installReady=`oc get csv -n monitoring-grafana "$csv" -o json | jq -r '.status.phase == "Succeeded"'`
    fi

    if [ "$installReady" != true ]
    then
        sleep 5
    fi
done

oc create -n monitoring-grafana -f - <<EOF
apiVersion: integreatly.org/v1alpha1
kind: Grafana
metadata:
  name: grafana
spec:
  baseImage: docker.io/grafana/grafana-oss:9.4.7
  config:
    log:
      mode: "console"
      level: "warn"
    auth:
      disable_login_form: false
      disable_signout_menu: true
    auth.basic:
      enabled: true
    auth.anonymous:
      enabled: true
      org_role: Admin
  deployment:
    env:
      - name: GRAFANA_TOKEN
        valueFrom:
          secretKeyRef:
            name: grafana-auth-secret
            key: token
  containers:
    - env:
        - name: SAR
          value: '-openshift-sar={"resource": "namespaces", "verb": "get"}'
      args:
        - '-provider=openshift'
        - '-pass-basic-auth=false'
        - '-https-address=:9091'
        - '-http-address='
        - '-email-domain=*'
        - '-upstream=http://localhost:3000'
        - "\$(SAR)"
        - '-openshift-delegate-urls={"/": {"resource": "namespaces", "verb": "get"}}'
        - '-tls-cert=/etc/tls/private/tls.crt'
        - '-tls-key=/etc/tls/private/tls.key'
        - '-client-secret-file=/var/run/secrets/kubernetes.io/serviceaccount/token'
        - '-cookie-secret-file=/etc/proxy/secrets/session_secret'
        - '-openshift-service-account=grafana-serviceaccount'
        - '-openshift-ca=/etc/pki/tls/cert.pem'
        - '-openshift-ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
        - '-skip-auth-regex=^/metrics'
      image: 'registry.redhat.io/openshift4/ose-oauth-proxy:v4.10'
      imagePullPolicy: Always
      name: grafana-proxy
      ports:
        - containerPort: 9091
          name: grafana-proxy
      resources: {}
      volumeMounts:
        - mountPath: /etc/tls/private
          name: secret-grafana-k8s-tls
          readOnly: false
        - mountPath: /etc/proxy/secrets
          name: secret-grafana-k8s-proxy
          readOnly: false
  secrets:
    - grafana-k8s-tls
    - grafana-k8s-proxy
  service:
    ports:
      - name: grafana-proxy
        port: 9091
        protocol: TCP
        targetPort: grafana-proxy
    annotations:
      service.alpha.openshift.io/serving-cert-secret-name: grafana-k8s-tls
  ingress:
    enabled: true
    targetPort: grafana-proxy
    termination: reencrypt
  client:
    preferService: true
  serviceAccount:
    annotations:
      serviceaccounts.openshift.io/oauth-redirectreference.primary: '{"kind":"OAuthRedirectReference","apiVersion":"v1","reference":{"kind":"Route","name":"grafana-route"}}'
  dashboardLabelSelector:
    - matchExpressions:
        - { key: "app", operator: In, values: ['grafana'] }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: grafana-proxy
rules:
  - apiGroups:
      - authentication.k8s.io
    resources:
      - tokenreviews
    verbs:
      - create
  - apiGroups:
      - authorization.k8s.io
    resources:
      - subjectaccessreviews
    verbs:
      - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: grafana-proxy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: grafana-proxy
subjects:
  - kind: ServiceAccount
    name: grafana-serviceaccount
---
apiVersion: v1
data:
  session_secret: Y2hhbmdlIG1lCg==
kind: Secret
metadata:
  name: grafana-k8s-proxy
type: Opaque
EOF

waitForStatus \
  grafanas.integreatly.org \
  grafana \
  400 \
  10 \
  '{.status.phase}' \
  'failing'

# Ignore error if svc grafana-alert has no annotations
oc patch svc grafana-alert --type=json -p='[{"op": "remove", "path": "/metadata/annotations"}]' || true
oc delete secret grafana-k8s-tls
oc annotate service grafana-service fixed=yes

oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount -n monitoring-grafana

oc create -n monitoring-grafana -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: grafana-auth-secret
  annotations:
    kubernetes.io/service-account.name: grafana-serviceaccount
type: kubernetes.io/service-account-token
EOF

oc create -n monitoring-grafana -f - <<EOF
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDataSource
metadata:
  name: prometheus
spec:
  datasources:
    - access: proxy
      editable: true
      isDefault: true
      jsonData:
        httpHeaderName1: 'Authorization'
        timeInterval: 5s
        tlsSkipVerify: true
      name: prometheus
      secureJsonData:
        httpHeaderValue1: 'Bearer \${GRAFANA_TOKEN}'
      type: prometheus
      url: 'https://thanos-querier.openshift-monitoring.svc.cluster.local:9091'
  name: prometheus.yaml
EOF

echo "Monitoring will be available at https://$(oc get route -n monitoring-grafana grafana-route -o jsonpath='{.status.ingress[0].host}')"