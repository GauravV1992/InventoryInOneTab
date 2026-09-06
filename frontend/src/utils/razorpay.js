export function loadRazorpayScript() {
  return new Promise((resolve) => {
    if (window.Razorpay) {
      resolve(true);
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.onload = () => resolve(true);
    script.onerror = () => resolve(false);
    document.body.appendChild(script);
  });
}

export async function openRazorpayCheckout({ keyId, orderId, amountPaise, name, description, prefill, onSuccess }) {
  const loaded = await loadRazorpayScript();
  if (!loaded || !window.Razorpay) {
    throw new Error('Unable to load Razorpay checkout');
  }

  return new Promise((resolve, reject) => {
    const rzp = new window.Razorpay({
      key: keyId,
      amount: amountPaise,
      currency: 'INR',
      name: name || 'InventoryInOneTap',
      description: description || 'Subscription',
      order_id: orderId,
      prefill: prefill || {},
      theme: { color: '#f97316' },
      handler(response) {
        onSuccess(response);
        resolve(response);
      },
      modal: {
        ondismiss() {
          reject(new Error('Payment cancelled'));
        },
      },
    });
    rzp.open();
  });
}
